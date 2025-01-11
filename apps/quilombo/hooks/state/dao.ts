'use client';

import { atom, useAtom } from 'jotai';
import { useCallback, useEffect } from 'react';
import { usePublicClient } from 'wagmi';

import ENV from '@/config/environment';
import { baalAbi } from '@/generated';

export interface Proposal {
  id: bigint;
  proposalDataHash: `0x${string}`;
  votingPeriod: number;
  expiration: number;
  baalGas: bigint;
  timestamp: number;
  details: string;
  status: 'active' | 'executed' | 'cancelled' | 'failed';
}

export interface ProposalsState {
  proposals: Map<bigint, Proposal>;
  loading: boolean;
  initialized: boolean;
}

export const proposalsAtom = atom<ProposalsState>({
  proposals: new Map(),
  loading: false,
  initialized: false,
});

export const activeProposalsAtom = atom<Map<bigint, Proposal>>((get) => {
  const proposals = get(proposalsAtom);
  return new Map(Array.from(proposals.proposals.entries()).filter(([, proposal]) => proposal.status === 'active'));
});

export function useProposals() {
  const [state, setState] = useAtom(proposalsAtom);
  const publicClient = usePublicClient();

  console.log('Chain ID: ', publicClient?.chain.id);

  const loadProposals = useCallback(async () => {
    if (!publicClient) return;

    console.log('Loading historical proposals for DAO:', ENV.axeDaoAddress);
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

      console.log('Raw Submit Events:', submitLogs);
      console.log('Raw Process Events:', processLogs);
      console.log('Raw Cancel Events:', cancelLogs);

      // Track proposal statuses
      const proposalStatuses = new Map<bigint, 'executed' | 'failed' | 'cancelled'>([
        ...processLogs.map((log) => {
          const args = log.args as { proposal: bigint; passed: boolean };
          return [args.proposal, args.passed ? 'executed' : 'failed'] as const;
        }),
        ...cancelLogs.map((log) => {
          const args = log.args as { proposal: bigint };
          return [args.proposal, 'cancelled'] as const;
        }),
      ]);

      const proposalResults = new Map<bigint, Proposal>();

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

        const id = args.proposal;
        const timestamp = Number(args.timestamp);
        const expiration = timestamp + Number(args.votingPeriod);
        const isExpired = expiration < Date.now() / 1000;

        const status = proposalStatuses.get(id) || (isExpired ? 'cancelled' : 'active');

        const result: Proposal = {
          id,
          proposalDataHash: args.proposalDataHash,
          votingPeriod: Number(args.votingPeriod),
          expiration,
          baalGas: args.baalGas,
          timestamp,
          details: args.details,
          status,
        };

        console.log('Proposal:', result);
        proposalResults.set(id, result);
      });

      console.log('All proposals:', Array.from(proposalResults.entries()));
      setState((prev) => ({ ...prev, proposals: proposalResults, initialized: true }));
    } catch (error) {
      console.error('Error loading proposals:', error);
    } finally {
      setState((prev) => ({ ...prev, loading: false }));
    }
  }, [publicClient, setState]);

  useEffect(() => {
    if (!state.initialized && !state.loading) {
      loadProposals();
    }
  }, [loadProposals, state]);

  return { ...state, refresh: loadProposals };
}
