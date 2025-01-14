'use client';

import { useWriteMembershipCouncilResignAsCandidate } from '@/generated';
import { useCandidates, useHasLootShares } from '@/hooks/state/dao';
import { Button } from '@nextui-org/button';
import { useDisclosure } from '@nextui-org/use-disclosure';
import { useSnackbar } from 'notistack';
import { useEffect } from 'react';
import { Address } from 'viem';
import { useAccount, useWaitForTransactionReceipt } from 'wagmi';
import { CouncilBadge } from './Badges';
import CouncilEligibilityModal from './CouncilEligibilityModal';
import VoteDelegation from './VoteDelegation';

import ENV from '@/config/environment';
import { useReadMembershipCouncilIsMember } from '@/generated';

const CouncilMembership: React.FC = () => {
  const account = useAccount();
  const { isOpen, onOpen, onOpenChange, onClose } = useDisclosure();
  const { enqueueSnackbar } = useSnackbar();

  // Check if user is DAO member
  const { data: isMember = false } = useReadMembershipCouncilIsMember({
    address: ENV.membershipCouncilAddress,
    args: [account.address as Address],
  });

  // Check if user is council member or candidate
  const hasLootShares = useHasLootShares();
  const { addresses: candidateAddresses, refresh } = useCandidates();
  const isCandidate = !!account.address && candidateAddresses.includes(account.address);

  const {
    data: resignHash,
    isPending: resignPending,
    writeContract: resign,
  } = useWriteMembershipCouncilResignAsCandidate();

  const {
    isSuccess: resignSuccess,
    error: resignError,
    isLoading: resignLoading,
  } = useWaitForTransactionReceipt({ hash: resignHash });

  // Handle resign transaction states
  useEffect(() => {
    if (resignLoading) {
      enqueueSnackbar('Resigning as candidate. Please wait for confirmation...', {
        autoHideDuration: 3000,
      });
    } else if (resignSuccess) {
      enqueueSnackbar('Successfully resigned as candidate!');
      refresh();
    } else if (resignError) {
      enqueueSnackbar(`Failed to resign: ${resignError.message}`, { variant: 'error' });
    }
  }, [resignLoading, resignSuccess, resignError, refresh, enqueueSnackbar]);

  // Don't show button if already candidate or council member
  if (hasLootShares || isCandidate) {
    return (
      <div className="flex flex-col gap-2 sm:gap-4 w-full">
        <div className="flex gap-2 sm:gap-4">
          <CouncilBadge isCouncil={hasLootShares} />
          <span>{hasLootShares ? 'Council Member' : 'Council Candidate'}</span>
        </div>
        {isCandidate && (
          <Button
            color="danger"
            variant="flat"
            onPress={() => resign({ address: ENV.membershipCouncilAddress })}
            isLoading={resignPending || resignLoading}
          >
            Resign as Candidate
          </Button>
        )}
        {isMember && <VoteDelegation />}
      </div>
    );
  }

  return (
    <div className="flex flex-col w-full items-center">
      <div className="text-2xl mb-1 sm:mb-2">Council Membership</div>
      <div className="flex flex-col gap-2 sm:gap-4 w-full">
        <Button onPress={onOpen} color="primary" className="w-full" isDisabled={!isMember}>
          {isMember ? 'Enlist as Candidate' : 'Become Eligible'}
        </Button>
        <CouncilEligibilityModal
          isOpen={isOpen}
          onOpenChange={onOpenChange}
          hasLootShares={hasLootShares}
          onClose={onClose}
        />
      </div>
    </div>
  );
};

export default CouncilMembership;
