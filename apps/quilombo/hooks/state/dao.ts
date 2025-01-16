'use client';

import { divide, format, from, greaterThan, multiply } from 'dnum';
import { atom, useAtom } from 'jotai';
import { useCallback, useEffect } from 'react';
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
  useWriteAxeMembershipCouncilRequestCouncilUpdate,
} from '@/generated';
import { useSearchUsersByAddresses } from '@/query/user';
import { User } from '@/types/model';
import { Address } from 'viem';

export interface Proposal {
  id: number;
  proposalDataHash: `0x${string}`;
  votingPeriod: number;
  expiration: number;
  details: string;
  status: 'submitted' | 'voting' | 'cancelled' | 'grace' | 'ready' | 'processed' | 'defeated' | 'failed';
  timestamp: number;
}

export const PROPOSAL_STATUS = {
  VOTING: 'voting',
  GRACE: 'grace',
  READY: 'ready',
  PROCESSED: 'processed',
  DEFEATED: 'defeated',
  FAILED: 'failed',
  CANCELLED: 'cancelled',
} as const;

export type ProposalStatus = (typeof PROPOSAL_STATUS)[keyof typeof PROPOSAL_STATUS];

export const isProposalActive = (status: Proposal['status']): boolean => {
  return status === 'submitted' || status === 'voting' || status === 'grace' || status === 'ready';
};

export const isProposalFinal = (status: Proposal['status']): boolean => {
  return status === 'cancelled' || status === 'processed' || status === 'defeated';
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

// Add interface for timing object
interface ProposalTiming {
  now: number;
  votingEnds: number;
  gracePeriodEnds: number;
  inVoting: boolean;
  inGrace: boolean;
  pastGrace: boolean;
}

interface QuorumInfo {
  quorum: string;
  quorumPercent: string;
  totalShares: string;
  quorumNeeded: string;
  quorumMet: boolean;
}

// Update logging helper signature
const logProposalState = (
  id: number,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  voteResult: any,
  timing: ProposalTiming,
  status: string,
  quorum: QuorumInfo,
) => {
  console.log(`Proposal #${id} state:`, {
    timing: {
      now: Math.floor(timing.now),
      votingEnds: Math.floor(timing.votingEnds),
      gracePeriodEnds: Math.floor(timing.gracePeriodEnds),
      inVoting: timing.inVoting,
      inGrace: timing.inGrace,
      pastGrace: timing.pastGrace,
    },
    votes: voteResult
      ? {
          yes: voteResult[5]?.toString() ?? '0',
          no: voteResult[6]?.toString() ?? '0',
          totalVotes: (BigInt(voteResult[5] ?? 0) + BigInt(voteResult[6] ?? 0)).toString(),
        }
      : 'no vote result',
    finalStatus: status,
    quorum: {
      requirement: quorum.quorum,
      percentRequired: quorum.quorumPercent,
      totalShares: quorum.totalShares,
      needed: quorum.quorumNeeded,
      met: quorum.quorumMet,
    },
  });
};

export function useProposals() {
  const [state, setState] = useAtom(proposalsAtom);
  const publicClient = usePublicClient();

  // Add hook to get grace period from contract
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
      console.log('Missing required values:', {
        hasPublicClient: !!publicClient,
        hasGracePeriod: !!gracePeriod,
        hasQuorumPercent: !!quorumPercent,
        hasTotalShares: !!totalShares,
      });
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
        const now = Date.now() / 1000;

        // Initial state is 'submitted', then transitions to 'voting'
        const status: Proposal['status'] = now < timestamp ? 'submitted' : 'voting';

        proposalResults.set(id, {
          id,
          proposalDataHash: args.proposalDataHash,
          votingPeriod: Number(args.votingPeriod),
          expiration,
          details: args.details,
          status,
          timestamp,
        });
      });

      // First, get voting results for all proposals
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

      // Debug raw values first
      console.log('Raw quorum values:', {
        quorumPercent: quorumPercent.toString(),
        totalShares: totalShares.toString(),
      });

      // Calculate quorum requirement step by step
      const totalSharesDnum = from([totalShares, 18]); // 81 shares with 18 decimals
      const quorumPercentDnum = from([quorumPercent, 0]); // 51 = 51%
      const quorumDecimal = divide(quorumPercentDnum, from([100n, 0]), 2); // Convert 51 to 0.51 for 51%
      const quorumRequirement = multiply(totalSharesDnum, quorumDecimal);

      // Debug each step of calculation
      console.log('Quorum calculation steps:', {
        totalShares: {
          raw: totalShares?.toString(),
          formatted: format(totalSharesDnum),
          human: Number(format(totalSharesDnum)),
        },
        quorumPercent: {
          raw: quorumPercent?.toString(),
          basisPoints: Number(quorumPercent),
          asPercent: `${Number(quorumPercent)}%`,
          asDecimal: format(quorumDecimal),
        },
        requirement: {
          raw: format(quorumRequirement),
          human: Number(format(quorumRequirement)),
          scaled: format(multiply(quorumRequirement, from([BigInt(1e18), 0]))),
        },
      });

      // Update status based on events and voting results
      proposalResults.forEach((proposal) => {
        const voteResult = votingResults.find((v) => v.id === proposal.id)?.result;
        const nowSeconds = Math.floor(Date.now() / 1000);
        const votingEndTime = proposal.timestamp + proposal.votingPeriod;
        const gracePeriodEndTime = votingEndTime + Number(gracePeriod || 0);

        // Debug raw timing values
        console.log('Raw timing values:', {
          now: nowSeconds,
          votingEnds: votingEndTime,
          gracePeriodEnds: gracePeriodEndTime,
        });

        const now = from([BigInt(nowSeconds), 0]);
        const votingEnds = from([BigInt(votingEndTime), 0]);
        const gracePeriodEnds = from([BigInt(gracePeriodEndTime), 0]);

        const timing = {
          now: nowSeconds,
          votingEnds: votingEndTime,
          gracePeriodEnds: gracePeriodEndTime,
          inVoting: !greaterThan(now, votingEnds),
          inGrace: greaterThan(now, votingEnds) && !greaterThan(now, gracePeriodEnds),
          pastGrace: greaterThan(now, gracePeriodEnds),
        };

        let status = proposal.status;
        if (!greaterThan(now, votingEnds)) {
          status = PROPOSAL_STATUS.VOTING;
        } else if (!greaterThan(now, gracePeriodEnds)) {
          status = PROPOSAL_STATUS.GRACE;
        } else if (voteResult) {
          // Log raw vote result first
          console.log('Raw vote result:', {
            proposalId: proposal.id,
            result: voteResult,
            yes: voteResult[7]?.toString(),
            no: voteResult[8]?.toString(),
          });

          // Keep votes in their original unit (no decimals)
          const yesVotes = from([BigInt(voteResult[7]), 0]);
          const noVotes = from([BigInt(voteResult[8]), 0]);
          const totalVotes = from([BigInt(voteResult[7]) + BigInt(voteResult[8]), 0]);

          // Scale votes up to match shares (18 decimals)
          const scaledYesVotes = multiply(yesVotes, from([BigInt(1e18), 0]));
          const scaledNoVotes = multiply(noVotes, from([BigInt(1e18), 0]));
          const scaledTotalVotes = multiply(totalVotes, from([BigInt(1e18), 0]));

          // Debug vote scaling
          console.log('Vote scaling:', {
            raw: {
              yes: format(yesVotes),
              no: format(noVotes),
              total: format(totalVotes),
            },
            scaled: {
              yes: format(scaledYesVotes),
              no: format(scaledNoVotes),
              total: format(scaledTotalVotes),
            },
            quorum: format(quorumRequirement),
            quorumMet: greaterThan(scaledTotalVotes, quorumRequirement),
          });

          // Check quorum first using scaled votes
          if (!greaterThan(scaledTotalVotes, quorumRequirement)) {
            status = PROPOSAL_STATUS.FAILED;
          } else {
            // Quorum met, check vote outcome (using unscaled votes)
            status = greaterThan(noVotes, yesVotes) ? PROPOSAL_STATUS.DEFEATED : PROPOSAL_STATUS.READY;
          }

          // Update logging
          logProposalState(proposal.id, voteResult, timing, status, {
            quorum: format(quorumRequirement),
            quorumPercent: `${format(quorumPercentDnum)}%`,
            totalShares: format(totalSharesDnum),
            quorumNeeded: format(quorumRequirement),
            quorumMet: greaterThan(totalVotes, quorumRequirement),
          });
        }

        proposal.status = status;
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

      // Debug logs for events
      console.log(
        'Submit logs:',
        submitLogs.map((log) => ({
          id: Number(log.args.proposal),
          timestamp: Number(log.args.timestamp),
          votingPeriod: Number(log.args.votingPeriod),
          blockNumber: Number(log.blockNumber),
        })),
      );

      // Log voting results
      console.log(
        'Voting results:',
        votingResults.map((v) => ({
          id: v.id,
          result: v.result,
        })),
      );

      // Log final proposal states
      console.log(
        'Final proposal states:',
        Array.from(proposalResults.values()).map((p) => ({
          id: p.id,
          status: p.status,
          expiration: p.expiration,
          now: Date.now() / 1000,
          gracePeriodEnd: p.expiration + Number(gracePeriod),
        })),
      );

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

  const { data: canUpdate, isLoading: canUpdateLoading } = useReadAxeMembershipCouncilCanRequestCouncilUpdate({
    address: ENV.axeMembershipCouncilAddress,
  });

  const {
    writeContract: requestUpdate,
    data: updateHash,
    isPending: updatePending,
  } = useWriteAxeMembershipCouncilRequestCouncilUpdate();

  const { data: currentMembers, isLoading: membersLoading } = useReadAxeMembershipCouncilGetCurrentMembers({
    address: ENV.axeMembershipCouncilAddress,
  });

  const { data: councilUsers, isLoading: councilUsersLoading } = useSearchUsersByAddresses({
    addresses: currentMembers?.map((m) => m) ?? [],
  });

  // Load council members
  const loadCouncilMembers = useCallback(async () => {
    if (!currentMembers || !councilUsers || !publicClient) return;
    setState((prev) => ({ ...prev, loading: true }));
    try {
      const memberPromises = currentMembers.map(async (address) => {
        const candidate = await publicClient.readContract({
          address: ENV.axeMembershipAddress,
          abi: axeMembershipAbi,
          functionName: 'getCandidate',
          args: [address],
        });

        return {
          walletAddress: address,
          delegationCount: candidate.delegationCount,
          available: candidate.available,
        };
      });

      const resolvedMembers = await Promise.all(memberPromises);

      // Merge candidate data with user data
      const mergedMembers = resolvedMembers.map((member) => {
        const user = councilUsers.find((user) => user.walletAddress === member.walletAddress);
        if (!user) {
          console.warn(`No user data found for council member ${member.walletAddress}`);
        }
        return {
          ...member,
          ...(user || {}), // Spread user properties if found, empty object if not
        } as CandidateUser;
      });

      setState((prev) => ({
        ...prev,
        members: mergedMembers,
        initialized: true,
        error: null,
      }));
    } catch (error) {
      console.error('Error loading council:', error);
      setState((prev) => ({ ...prev, error: 'Failed to load council members' }));
    } finally {
      setState((prev) => ({ ...prev, loading: false }));
    }
  }, [currentMembers, councilUsers, publicClient, setState]);

  return {
    members: state.members,
    isLoading: state.loading || membersLoading || canUpdateLoading || councilUsersLoading,
    error: state.error,
    canUpdate,
    requestUpdate: () => requestUpdate({ address: ENV.axeMembershipCouncilAddress }),
    isUpdatePending: updatePending,
    updateHash,
    refresh: loadCouncilMembers,
  };
}
