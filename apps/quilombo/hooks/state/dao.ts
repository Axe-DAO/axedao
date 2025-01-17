'use client';

import { add, divide, from, greaterThan, multiply } from 'dnum';
import { atom, useAtom } from 'jotai';
import { useCallback, useEffect, useMemo, useRef } from 'react';
import { useAccount, usePublicClient } from 'wagmi';

import ENV from '@/config/environment';
import {
  axeMembershipAbi,
  baalAbi,
  useReadAxeMembershipCouncilCanRequestCouncilUpdate,
  useReadAxeMembershipCouncilGetCurrentMembers,
  useReadErc20BalanceOf,
  useReadErc20TotalSupply,
  useReadIBaalGracePeriod,
  useReadIBaalQuorumPercent,
} from '@/generated';
import { useSearchUsersByAddresses } from '@/query/user';
import { User } from '@/types/model';
import { Address } from 'viem';

// copied from baal-sdk
export const PROPOSAL_STATUS = {
  VOTING: 'voting',
  GRACE: 'grace',
  READY: 'ready',
  PROCESSED: 'processed',
  DEFEATED: 'defeated',
  FAILED: 'failed',
  CANCELLED: 'cancelled',
} as const;

export interface Proposal {
  id: number;
  proposalDataHash: `0x${string}`;
  votingPeriod: number;
  expiration: number;
  details: string;
  status: ProposalStatus;
  timestamp: number;
}

export type ProposalStatus = (typeof PROPOSAL_STATUS)[keyof typeof PROPOSAL_STATUS];

export const isProposalActive = (status: ProposalStatus): boolean => {
  return status === PROPOSAL_STATUS.VOTING || status === PROPOSAL_STATUS.GRACE || status === PROPOSAL_STATUS.READY;
};

export const isProposalFinal = (status: ProposalStatus): boolean => {
  return (
    status === PROPOSAL_STATUS.CANCELLED ||
    status === PROPOSAL_STATUS.PROCESSED ||
    status === PROPOSAL_STATUS.DEFEATED ||
    status === PROPOSAL_STATUS.FAILED
  );
};

export interface ProposalsState {
  proposals: Proposal[];
  loading: boolean;
  initialized: boolean;
  error: string | null;
}

export interface CandidatesState {
  addresses: Address[];
  loading: boolean;
  initialized: boolean;
  error: string | null;
}

export interface Candidate {
  walletAddress: Address;
  delegationCount: bigint;
  available: boolean;
}

export type CandidateUser = Candidate & User;

export interface CouncilState {
  members: CandidateUser[];
  loading: boolean;
  initialized: boolean;
  error: string | null;
}

export const proposalsAtom = atom<ProposalsState>({
  proposals: [],
  loading: false,
  initialized: false,
  error: null,
});

// Derived atom for easier access to only active proposals
export const activeProposalsAtom = atom<Proposal[]>((get) => {
  const { proposals } = get(proposalsAtom);
  return proposals.filter((proposal) => isProposalActive(proposal.status));
});

export const candidatesAtom = atom<CandidatesState>({
  addresses: [],
  loading: false,
  initialized: false,
  error: null,
});

export const councilAtom = atom<CouncilState>({
  members: [],
  loading: false,
  initialized: false,
  error: null,
});

export function useProposals() {
  const [state, setState] = useAtom(proposalsAtom);
  const publicClient = usePublicClient();

  const { data: gracePeriod } = useReadIBaalGracePeriod({
    address: ENV.daoAddress,
  });

  const { data: quorumPercent } = useReadIBaalQuorumPercent({
    address: ENV.daoAddress,
  });

  const { data: totalShares } = useReadErc20TotalSupply({
    address: ENV.daoSharesAddress,
  });

  const loadHistoricalProposalLogs = useCallback(async () => {
    if (!publicClient || !gracePeriod || !quorumPercent || !totalShares) {
      return;
    }

    setState((prev) => ({ ...prev, loading: true }));

    try {
      const [submitLogs, processLogs, cancelLogs] = await Promise.all([
        publicClient.getContractEvents({
          address: ENV.daoAddress,
          abi: baalAbi,
          eventName: 'SubmitProposal',
          fromBlock: 'earliest',
        }),
        publicClient.getContractEvents({
          address: ENV.daoAddress,
          abi: baalAbi,
          eventName: 'ProcessProposal',
          fromBlock: 'earliest',
        }),
        publicClient.getContractEvents({
          address: ENV.daoAddress,
          abi: baalAbi,
          eventName: 'CancelProposal',
          fromBlock: 'earliest',
        }),
      ]);

      // Track proposal lifecycle through events
      const proposalResults = new Map<number, Proposal>();

      // First, record all submitted proposals (initial state)
      submitLogs.forEach((log) => {
        const args = log.args as {
          proposal: bigint;
          proposalDataHash: `0x${string}`;
          votingPeriod: bigint;
          expiration: bigint;
          timestamp: bigint;
          details: string;
        };

        const id = Number(args.proposal);
        const timestamp = Number(args.timestamp);
        const expiration = timestamp + Number(args.votingPeriod);

        proposalResults.set(id, {
          id,
          proposalDataHash: args.proposalDataHash,
          votingPeriod: Number(args.votingPeriod),
          expiration,
          details: args.details,
          status: PROPOSAL_STATUS.VOTING, // Initial state is always voting when we see the event
          timestamp,
        });
      });

      // First, get voting results for all proposals
      // TODO: in the future, the number of historical proposals will be too large to fetch all at once,
      // so we need to paginate
      const votingResults = await Promise.all(
        Array.from(proposalResults.keys()).map(async (id) => {
          try {
            const result = await publicClient.readContract({
              address: ENV.daoAddress,
              abi: baalAbi,
              functionName: 'proposals',
              args: [BigInt(id)],
            });
            return { id, result };
          } catch (error) {
            console.error(`Error fetching voting results for proposal ${id}:`, error);
            return { id, result: null };
          }
        }),
      );

      // Calculate quorum requirement step by step
      const totalSharesDnum = from([totalShares, 18]); // 81 shares with 18 decimals
      const quorumPercentDnum = from([quorumPercent, 0]); // 51 = 51%
      const quorumDecimal = divide(quorumPercentDnum, from([100n, 0]), 2); // Convert 51 to 0.51 for 51%
      const quorumRequirement = multiply(totalSharesDnum, quorumDecimal);

      // Update status based on events and voting results
      proposalResults.forEach((proposal) => {
        const voteResult = votingResults.find((v) => v.id === proposal.id)?.result;
        const nowSeconds = Math.floor(Date.now() / 1000);
        const votingEndTime = proposal.timestamp + proposal.votingPeriod;
        const gracePeriodEndTime = votingEndTime + Number(gracePeriod || 0);

        let status: ProposalStatus;
        if (nowSeconds <= votingEndTime) {
          status = PROPOSAL_STATUS.VOTING;
        } else if (nowSeconds <= gracePeriodEndTime) {
          status = PROPOSAL_STATUS.GRACE;
        } else if (voteResult) {
          const yesVotes = from([voteResult[7], 18]);
          const noVotes = from([voteResult[8], 18]);
          const totalVotes = add(yesVotes, noVotes);

          // Check quorum using votes (already at 18 decimals)
          if (!greaterThan(totalVotes, quorumRequirement)) {
            status = PROPOSAL_STATUS.FAILED;
          } else {
            status = greaterThan(noVotes, yesVotes) ? PROPOSAL_STATUS.DEFEATED : PROPOSAL_STATUS.READY;
          }
          proposal.status = status;
        }
      });

      // Apply final states from events last (these override any other status)
      cancelLogs.forEach((log) => {
        const args = log.args as { proposal: bigint };
        const id = Number(args.proposal);
        if (proposalResults.has(id)) {
          proposalResults.get(id)!.status = PROPOSAL_STATUS.CANCELLED;
        }
      });

      processLogs.forEach((log) => {
        const args = log.args as { proposal: bigint; passed: boolean };
        const id = Number(args.proposal);
        if (proposalResults.has(id)) {
          proposalResults.get(id)!.status = args.passed ? PROPOSAL_STATUS.PROCESSED : PROPOSAL_STATUS.DEFEATED;
        }
      });

      // Convert to sorted array before storing
      const sortedProposals = Array.from(proposalResults.values()).sort((a, b) => Number(b.id - a.id)); // Sort by descending ID

      setState((prev) => ({
        ...prev,
        proposals: sortedProposals,
        initialized: true,
      }));
    } catch (error) {
      console.error('Error loading proposals:', error);
      setState((prev) => ({ ...prev, error: 'Error loading proposals' }));
    } finally {
      setState((prev) => ({ ...prev, loading: false }));
    }
  }, [publicClient, gracePeriod, quorumPercent, totalShares, setState]);

  useEffect(() => {
    if (!state.initialized && !state.loading) {
      loadHistoricalProposalLogs();
    }
  }, [loadHistoricalProposalLogs, state]);

  return { ...state, refresh: loadHistoricalProposalLogs };
}

export function useCandidates() {
  const [state, setState] = useAtom(candidatesAtom);
  const publicClient = usePublicClient();

  const {
    data: candidateUsers,
    isLoading: isLoadingUsers,
    error: loadingUsersError,
  } = useSearchUsersByAddresses({
    addresses: state.addresses,
  });

  const loadHistoricalCandidateLogs = useCallback(async () => {
    if (!publicClient) return;

    setState((prev) => ({ ...prev, loading: true, error: null }));

    try {
      const [enlistLogs, resignLogs] = await Promise.all([
        publicClient.getContractEvents({
          address: ENV.axeMembershipAddress,
          abi: axeMembershipAbi,
          eventName: 'CandidateEnlisted',
          fromBlock: 'earliest',
        }),
        publicClient.getContractEvents({
          address: ENV.axeMembershipAddress,
          abi: axeMembershipAbi,
          eventName: 'CandidateResigned',
          fromBlock: 'earliest',
        }),
      ]);

      const allEvents = [...enlistLogs, ...resignLogs].sort((a, b) => {
        const blockDiff = Number(a.blockNumber - b.blockNumber);
        return blockDiff === 0 ? Number(a.transactionIndex - b.transactionIndex) : blockDiff;
      });

      const candidateStatus = new Map<Address, boolean>();
      allEvents.forEach((log) => {
        const args = log.args as { candidate: Address };
        candidateStatus.set(args.candidate, log.eventName === 'CandidateEnlisted');
      });

      const addresses = Array.from(candidateStatus.entries())
        .filter(([address, isEnlisted]) => isEnlisted && address)
        .map(([address]) => address);

      setState((prev) => ({
        ...prev,
        addresses,
        initialized: true,
      }));
    } catch (error) {
      console.error('Error retrieving candidate event logs:', error);
      setState((prev) => ({ ...prev, error: 'Error retrieving candidate event logs' }));
    } finally {
      setState((prev) => ({ ...prev, loading: false }));
    }
  }, [publicClient, setState]);

  useEffect(() => {
    if (!state.initialized && !state.loading) {
      loadHistoricalCandidateLogs();
    }
  }, [loadHistoricalCandidateLogs, state.initialized, state.loading]);

  return {
    ...state,
    candidates: candidateUsers,
    isLoading: state.loading || isLoadingUsers,
    error: state.error ?? loadingUsersError,
    refresh: loadHistoricalCandidateLogs,
  };
}

export function useVotingShares() {
  const account = useAccount();

  const {
    data: balance,
    isLoading,
    error,
    refetch,
  } = useReadErc20BalanceOf({
    address: ENV.daoSharesAddress,
    args: [account.address as Address],
  });

  return { balance, isLoading, error, refetch };
}

export function useLootShares() {
  const account = useAccount();

  const {
    data: balance,
    isLoading,
    error,
    refetch,
  } = useReadErc20BalanceOf({
    address: ENV.daoLootAddress,
    args: [account.address as Address],
  });

  return { balance, isLoading, error, refetch };
}

export function useCouncil() {
  const [state, setState] = useAtom(councilAtom);
  const publicClient = usePublicClient();

  const renderCount = useRef(0);
  renderCount.current++;

  const { data: currentMembers, isLoading: membersLoading } = useReadAxeMembershipCouncilGetCurrentMembers({
    address: ENV.axeMembershipCouncilAddress,
  });

  const { data: canUpdate, isLoading: canUpdateLoading } = useReadAxeMembershipCouncilCanRequestCouncilUpdate({
    address: ENV.axeMembershipCouncilAddress,
  });

  const { data: councilUsers, isLoading: councilUsersLoading } = useSearchUsersByAddresses({
    addresses: currentMembers?.map((m) => m) ?? [],
  });

  // Memoize loading state
  const isLoading = useMemo(
    () => state.loading || membersLoading || canUpdateLoading || councilUsersLoading,
    [state.loading, membersLoading, canUpdateLoading, councilUsersLoading],
  );

  console.log('[useCouncil] Render #%d: %o', renderCount.current, {
    initialized: state.initialized,
    loading: isLoading,
    membersLoading,
    hasMembers: !!currentMembers,
    memberCount: currentMembers?.length ?? 0,
  });

  const loadCouncilMembers = useCallback(async () => {
    if (!currentMembers || !councilUsers || !publicClient || state.initialized) {
      console.log('[useCouncil] Skipping load:', {
        hasCurrentMembers: !!currentMembers,
        hasCouncilUsers: !!councilUsers,
        hasPublicClient: !!publicClient,
        isInitialized: state.initialized,
      });
      return;
    }

    console.log('[useCouncil] Starting load of council members');
    setState((prev) => ({ ...prev, loading: true }));

    try {
      console.time('useCouncil-multicall');
      const multicallCandidates = currentMembers.map((address) => ({
        address: ENV.axeMembershipAddress,
        abi: axeMembershipAbi,
        functionName: 'getCandidate',
        args: [address],
      }));

      const candidateResults = await publicClient.multicall({
        contracts: multicallCandidates,
      });
      console.timeEnd('useCouncil-multicall');

      console.time('useCouncil-merge-data');
      const mergedMembers = currentMembers
        .map((address, index) => {
          const result = candidateResults[index].result;
          if (!result || typeof result !== 'object') {
            console.warn(`Invalid candidate data for ${address}`);
            return null;
          }

          const delegationCount = result[0] as bigint;
          const available = result[1] as boolean;
          const user = councilUsers.find((user) => user.walletAddress === address);

          return {
            walletAddress: address,
            delegationCount,
            available,
            ...(user || {}),
          } as CandidateUser;
        })
        .filter((member): member is CandidateUser => member !== null);
      console.timeEnd('useCouncil-merge-data');

      setState((prev) => ({
        ...prev,
        members: mergedMembers,
        initialized: true,
        error: null,
      }));
    } catch (error) {
      console.error('[useCouncil] Error:', error);
    } finally {
      console.log('[useCouncil] Finished loading');
      setState((prev) => ({ ...prev, loading: false }));
    }
  }, [currentMembers, councilUsers, publicClient, state.initialized, setState]);

  useEffect(() => {
    if (!state.initialized && !isLoading) {
      console.log('[useCouncil] Effect triggered load');
      loadCouncilMembers();
    }
  }, [loadCouncilMembers, state.initialized, isLoading]);

  return {
    members: state.members,
    isLoading,
    error: state.error,
    canUpdate,
    isUpdating: false,
    updateHash: '',
    requestUpdate: () => Promise.resolve(),
    refresh: loadCouncilMembers,
  };
}
