import { Address, PublicClient } from 'viem';

import ENV from '@/config/environment';
import { axeMembershipAbi } from '@/generated';
import { Candidate } from '@/hooks/state/dao';
import { GetCandidatesParams, QUERY_KEYS } from '.';

/**
 * Returns query options for retrieving a Record of candidates containing their delegation count and
 * availability, indexed by wallet address.
 * @param addresses - The list of addresses to retrieve candidates for.
 * @param publicClient - The public client to use for the query.
 * @returns Query options for the getCandidates query.
 */
export const getCandidatesDictionaryOptions = ({ addresses, publicClient }: GetCandidatesParams) => {
  return {
    enabled: !!publicClient && !!addresses,
    queryKey: [QUERY_KEYS.membership.getCandidates, addresses],
    queryFn: async (): Promise<Record<Address, Candidate>> => {
      const multicallCandidates = addresses.map((address: string) => ({
        address: ENV.axeMembershipAddress,
        abi: axeMembershipAbi,
        functionName: 'getCandidate',
        args: [address],
      }));

      const results = publicClient
        ? await publicClient.multicall({
            contracts: multicallCandidates,
          })
        : [];

      return addresses.reduce(
        (acc, address, index) => {
          const result = results[index].result;
          if (result && typeof result === 'object') {
            acc[address as Address] = {
              walletAddress: address as Address,
              delegationCount: Number(result[0]),
              available: result[1] as boolean,
            };
          }
          return acc;
        },
        {} as Record<Address, Candidate>,
      );
    },
  } as const;
};

/**
 * Returns query options for all historical candidate addresses in AxeMembership contract based on
 * CandidateEnlisted and CandidateResigned events.
 * @param publicClient - The public client to use for the query.
 * @returns Query options for the getCandidateAddresses query.
 */
export const getCandidateAddressesOptions = ({ publicClient }: { publicClient?: PublicClient }) => ({
  enabled: !!publicClient,
  queryKey: [QUERY_KEYS.membership.getAllCandidateAddresses],
  queryFn: async (): Promise<Address[]> => {
    if (!publicClient) return [];

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

    // Get all unique addresses that were ever candidates
    const uniqueCandidates = new Set<Address>();
    [...enlistLogs, ...resignLogs].forEach((log) => {
      const args = log.args as { candidate: Address };
      uniqueCandidates.add(args.candidate);
    });

    return Array.from(uniqueCandidates);
  },
});
