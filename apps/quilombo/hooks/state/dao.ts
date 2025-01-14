'use client';

import { atom, useAtom } from 'jotai';
import { useCallback, useEffect } from 'react';
import { useAccount, usePublicClient } from 'wagmi';

import ENV from '@/config/environment';
import { baalAbi, membershipCouncilAbi, useReadErc20BalanceOf } from '@/generated';
import { useSearchUsersByAddresses } from '@/query/user';
import { Address } from 'viem';

export interface Proposal {
  id: number;
  proposalDataHash: `0x${string}`;
  votingPeriod: number;
  expiration: number;
  details: string;
  status: 'active' | 'executed' | 'cancelled' | 'failed';
}

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

export const proposalsAtom = atom<ProposalsState>({
  proposals: [],
  loading: false,
  initialized: false,
  error: null,
});

// Derived atom for easier access to only active proposals
export const activeProposalsAtom = atom<Proposal[]>((get) => {
  const { proposals } = get(proposalsAtom);
  return proposals.filter((proposal) => proposal.status === 'active');
});

export const candidatesAtom = atom<CandidatesState>({
  addresses: [],
  loading: false,
  initialized: false,
  error: null,
});

export function useProposals() {
  const [state, setState] = useAtom(proposalsAtom);
  const publicClient = usePublicClient();

  const loadHistoricalProposalLogs = useCallback(async () => {
    if (!publicClient) return;

    setState((prev) => ({ ...prev, loading: true }));

    try {
      const [submitLogs, processLogs, cancelLogs] = await Promise.all([
        publicClient.getContractEvents({
          address: ENV.axeDaoAddress,
          abi: baalAbi,
          eventName: 'SubmitProposal',
          fromBlock: 'earliest',
        }),
        publicClient.getContractEvents({
          address: ENV.axeDaoAddress,
          abi: baalAbi,
          eventName: 'ProcessProposal',
          fromBlock: 'earliest',
        }),
        publicClient.getContractEvents({
          address: ENV.axeDaoAddress,
          abi: baalAbi,
          eventName: 'CancelProposal',
          fromBlock: 'earliest',
        }),
      ]);

      // Track proposal statuses
      const proposalStatuses = new Map<number, 'executed' | 'failed' | 'cancelled'>([
        ...processLogs.map((log) => {
          const args = log.args as { proposal: bigint; passed: boolean };
          return [Number(args.proposal), args.passed ? 'executed' : 'failed'] as const;
        }),
        ...cancelLogs.map((log) => {
          const args = log.args as { proposal: bigint };
          return [Number(args.proposal), 'cancelled'] as const;
        }),
      ]);

      const proposalResults = new Map<number, Proposal>();

      // Parse submit logs
      submitLogs.forEach((log) => {
        const args = log.args as {
          proposal: bigint;
          proposalData: string;
          proposalDataHash: `0x${string}`;
          votingPeriod: bigint;
          expiration: bigint;
          baalGas: bigint;
          timestamp: bigint;
          details: string;
        };

        const id = Number(args.proposal);
        const timestamp = Number(args.timestamp);
        const expiration = timestamp + Number(args.votingPeriod);
        const isExpired = expiration < Date.now() / 1000;

        const status = proposalStatuses.get(id) || (isExpired ? 'cancelled' : 'active');

        const result: Proposal = {
          id,
          proposalDataHash: args.proposalDataHash,
          votingPeriod: Number(args.votingPeriod),
          expiration,
          details: args.details,
          status,
        };

        proposalResults.set(id, result);
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
  }, [publicClient, setState]);

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
          address: ENV.membershipCouncilAddress,
          abi: membershipCouncilAbi,
          eventName: 'CandidateEnlisted',
          fromBlock: 'earliest',
        }),
        publicClient.getContractEvents({
          address: ENV.membershipCouncilAddress,
          abi: membershipCouncilAbi,
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
        const args = log.args as { _candidate: Address };
        candidateStatus.set(args._candidate, log.eventName === 'CandidateEnlisted');
      });

      const addresses = Array.from(candidateStatus.entries())
        .filter(([, isEnlisted]) => isEnlisted)
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

export function useHasVotingShares() {
  const account = useAccount();

  const { data: shares } = useReadErc20BalanceOf({
    address: ENV.axeDaoSharesAddress,
    args: [account.address as Address],
  });

  return shares ? shares > 0n : false;
}

export function useHasLootShares() {
  const account = useAccount();

  const { data: shares } = useReadErc20BalanceOf({
    address: ENV.axeDaoLootAddress,
    args: [account.address as Address],
  });

  return shares ? shares > 0n : false;
}
