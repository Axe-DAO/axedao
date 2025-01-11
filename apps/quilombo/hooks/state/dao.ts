'use client';

import { atom, useAtom } from 'jotai';
import { useCallback, useEffect } from 'react';
import { Address } from 'viem';
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

export function useProposals() {
  const [state, setState] = useAtom(proposalsAtom);
  const publicClient = usePublicClient();

  console.log('Chain ID: ', publicClient?.chain.id);

  const loadProposals = useCallback(async () => {
    if (!publicClient) return;

    console.log('🔄 Loading historical proposals for DAO:', ENV.axeDaoAddress);
    setState((prev) => ({ ...prev, loading: true }));

    try {
      const [submitLogs, processLogs] = await Promise.all([
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
      ]);

      console.log('📝 Raw Submit Events:', submitLogs);
      console.log('⚙️ Raw Process Events:', processLogs);

      // Track processed proposals
      const processedProposalIds = new Set<bigint>(
        processLogs.map((log) => (log.args as { proposalId: bigint }).proposalId),
      );

      const newProposals = new Map<bigint, Proposal>();

      // Parse submit logs
      submitLogs.forEach((log) => {
        const args = log.args as {
          proposalId: bigint;
          proposalDataHash: Address;
          votingPeriod: bigint;
          expiration: bigint;
          baalGas: bigint;
          timestamp: bigint;
          details: string;
        };

        const id = args.proposalId;

        // Skip if proposal is processed
        if (processedProposalIds.has(id)) return;

        // Add to proposals map
        newProposals.set(id, {
          id,
          proposalDataHash: args.proposalDataHash,
          votingPeriod: Number(args.votingPeriod),
          expiration: Number(args.expiration),
          baalGas: args.baalGas,
          timestamp: Number(args.timestamp),
          details: args.details,
          status: 'active',
        });
      });

      console.log('Active proposals:', Array.from(newProposals.entries()));
      setState((prev) => ({ ...prev, proposals: newProposals, initialized: true }));
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
