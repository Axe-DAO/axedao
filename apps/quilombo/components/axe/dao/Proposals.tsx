'use client';

import { Accordion, AccordionItem, Button, Checkbox } from '@nextui-org/react';
import { CheckCircle2, Clock, XCircle } from 'lucide-react';
import { useSnackbar } from 'notistack';
import { useEffect, useMemo, useState } from 'react';
import { useWaitForTransactionReceipt } from 'wagmi';

import ENV from '@/config/environment';
import { useWriteIBaalSubmitVote } from '@/generated';
import { useProposals, useVotingShares } from '@/hooks/state/dao';

export default function Proposals() {
  const [showOldProposals, setShowOldProposals] = useState(false);
  const { enqueueSnackbar } = useSnackbar();
  const { proposals, loading, error } = useProposals();
  const { balance: votingShares, isLoading: votingSharesLoading } = useVotingShares();
  const isVotingEligible = useMemo(() => !!votingShares && votingShares > 0n, [votingShares]);

  // Filter proposals based on showOldProposals state
  const visibleProposals = useMemo(() => {
    return showOldProposals ? proposals : proposals.filter((p) => p.status === 'active');
  }, [proposals, showOldProposals]);

  // Contract interaction hooks
  const {
    writeContract: submitVote,
    data: voteHash,
    isPending: isVotePending,
    error: voteWriteError,
  } = useWriteIBaalSubmitVote();

  const {
    isSuccess: voteSuccess,
    error: voteError,
    isLoading: voteLoading,
  } = useWaitForTransactionReceipt({ hash: voteHash });

  // Handle vote transaction states
  useEffect(() => {
    if (voteLoading) {
      enqueueSnackbar('Submitting vote. Please wait for confirmation...', {
        autoHideDuration: 3000,
      });
    } else if (voteSuccess) {
      enqueueSnackbar('Vote submitted successfully!');
    } else if (voteError) {
      enqueueSnackbar(`Failed to vote: ${voteError.message}`, { variant: 'error' });
    }
  }, [voteLoading, voteSuccess, voteError, enqueueSnackbar]);

  // Add effect to catch write errors
  useEffect(() => {
    if (voteWriteError) {
      console.error('Vote write error:', voteWriteError);
      enqueueSnackbar(`Failed to initiate vote: ${voteWriteError.message}`, { variant: 'error' });
    }
  }, [voteWriteError, enqueueSnackbar]);

  const handleVote = (proposalId: number, approved: boolean) => {
    submitVote({
      address: ENV.daoAddress,
      args: [proposalId, approved],
    });
  };

  return (
    <div className="w-full">
      <div className="flex justify-end mb-4">
        <Checkbox isSelected={showOldProposals} onValueChange={setShowOldProposals}>
          Show Old Proposals
        </Checkbox>
      </div>

      {loading ? (
        <div>Loading proposals...</div>
      ) : visibleProposals.length > 0 ? (
        <Accordion variant="splitted">
          {visibleProposals.map((proposal) => {
            const details = JSON.parse(proposal.details);
            const isActive = proposal.status === 'active';

            return (
              <AccordionItem
                key={proposal.id.toString()}
                aria-label={`Proposal ${proposal.id.toString()}`}
                title={
                  <div className="flex items-center gap-2">
                    {proposal.status === 'active' && <Clock className="text-primary" size={20} />}
                    {proposal.status === 'cancelled' && <XCircle className="text-danger" size={20} />}
                    {proposal.status === 'executed' && <CheckCircle2 className="text-success" size={20} />}
                    {proposal.status === 'failed' && <CheckCircle2 className="text-danger" size={20} />}
                    <span className={isActive ? 'text-primary' : ''}>
                      {`#${proposal.id.toString()} - ${details.title}`}
                    </span>
                  </div>
                }
              >
                <div className="flex flex-col gap-2">
                  <div className="flex justify-between items-center">
                    <div className="text-sm">
                      <span className="font-semibold">Status:</span>{' '}
                      <span
                        className={`capitalize font-medium px-2 py-0.5 rounded-full text-xs ${
                          proposal.status === 'active'
                            ? 'bg-primary/20 text-primary'
                            : proposal.status === 'executed'
                              ? 'bg-success/20 text-success'
                              : 'bg-danger/20 text-danger'
                        }`}
                      >
                        {proposal.status}
                      </span>
                    </div>
                    {isActive && (
                      <div className="text-sm text-default-500">
                        Expires: {new Date(proposal.expiration * 1000).toLocaleString()}
                      </div>
                    )}
                  </div>

                  <div className="mt-2">
                    <div className="font-semibold mb-1">Description:</div>
                    <p className="text-sm text-default-500">{details.description}</p>
                  </div>

                  {isActive && (
                    <div className="flex flex-col gap-2 mt-4">
                      {votingSharesLoading ? (
                        <div className="text-sm text-default-500">Checking voting eligibility...</div>
                      ) : isVotingEligible ? (
                        <div className="flex gap-4">
                          <Button
                            color="success"
                            variant="flat"
                            isLoading={isVotePending || voteLoading}
                            onPress={() => handleVote(proposal.id, true)}
                          >
                            Vote Yes
                          </Button>
                          <Button
                            color="danger"
                            variant="flat"
                            isLoading={isVotePending || voteLoading}
                            onPress={() => handleVote(proposal.id, false)}
                          >
                            Vote No
                          </Button>
                        </div>
                      ) : (
                        <div className="text-sm text-warning">You need voting shares to vote on proposals.</div>
                      )}
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
      {error && <div className="text-red-500">{error}</div>}
    </div>
  );
}
