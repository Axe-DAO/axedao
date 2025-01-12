'use client';

import { useWriteBaalSubmitVote } from '@/generated';
import { useHasVotingShares, useProposals } from '@/hooks/state/dao';
import { Accordion, AccordionItem, Button } from '@nextui-org/react';
import { useCallback } from 'react';

export default function Proposals() {
  const { proposals, loading, error } = useProposals();
  const isCouncilMember = useHasVotingShares();
  const { writeContractAsync: submitVote, isPending: isVoting } = useWriteBaalSubmitVote();

  const handleVote = useCallback(
    async (proposalId: number, approved: boolean) => {
      try {
        await submitVote({ args: [proposalId, approved] });
      } catch (error) {
        console.error('Failed to vote:', error);
      }
    },
    [submitVote],
  );

  return (
    <div className="flex flex-col w-full items-center">
      <div className="text-2xl mb-1 sm:mb-2">Proposals</div>
      <div className="w-full">
        {loading ? (
          <div>Loading proposals...</div>
        ) : proposals.length > 0 ? (
          <Accordion variant="splitted">
            {proposals.map((proposal) => {
              const details = JSON.parse(proposal.details);
              const isActive = proposal.status === 'active';

              return (
                <AccordionItem
                  key={proposal.id.toString()}
                  aria-label={`Proposal ${proposal.id.toString()}`}
                  title={`#${proposal.id.toString()} - ${details.title}`}
                >
                  <div className="flex flex-col gap-2">
                    <div className="text-sm">
                      <span className="font-semibold">Status:</span>{' '}
                      <span className={`capitalize ${isActive ? 'text-green-500' : ''}`}>{proposal.status}</span>
                    </div>
                    <div className="text-sm">
                      <span className="font-semibold">Expires:</span>{' '}
                      {new Date(proposal.expiration * 1000).toLocaleString()}
                    </div>
                    <div className="mt-2">
                      <div className="font-semibold mb-1">Description:</div>
                      <p className="text-sm text-gray-300">{details.description}</p>
                    </div>

                    {isActive && isCouncilMember && (
                      <div className="flex gap-4 mt-4">
                        <Button
                          color="success"
                          variant="flat"
                          isLoading={isVoting}
                          onPress={() => handleVote(proposal.id, true)}
                        >
                          Vote Yes
                        </Button>
                        <Button
                          color="danger"
                          variant="flat"
                          isLoading={isVoting}
                          onPress={() => handleVote(proposal.id, false)}
                        >
                          Vote No
                        </Button>
                      </div>
                    )}
                  </div>
                </AccordionItem>
              );
            })}
          </Accordion>
        ) : (
          <div>No proposals found</div>
        )}
      </div>
      {error && <div className="text-red-500">{error}</div>}
    </div>
  );
}
