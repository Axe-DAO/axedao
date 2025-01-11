'use client';

import { useProposals } from '@/hooks/state/dao';

export default function Proposals() {
  const { proposals, loading } = useProposals();

  return (
    <div className="flex flex-col w-full items-center">
      <div className="text-2xl mb-1 sm:mb-2">Proposals</div>
      <div className="flex flex-col gap-2 sm:gap-4 w-full">
        {loading ? (
          <div>Loading proposals...</div>
        ) : proposals.size > 0 ? (
          Array.from(proposals.values()).map((proposal) => (
            <div key={proposal.id.toString()} className="p-4 bg-gray-800 rounded-lg">
              <div className="text-lg font-semibold">Proposal #{proposal.id.toString()}</div>
              <div className="mt-2 text-sm text-gray-300">{proposal.details}</div>
              <div className="mt-2 flex gap-4 text-sm text-gray-400">
                <div>Status: {proposal.status}</div>
                <div>Expires: {new Date(proposal.expiration * 1000).toLocaleDateString()}</div>
              </div>
            </div>
          ))
        ) : (
          <div>No proposals found</div>
        )}
      </div>
    </div>
  );
}
