'use client';

import { useWriteAxeMembershipResignAsCandidate } from '@/generated';
import { useCandidates, useLootShares } from '@/hooks/state/dao';
import { Button } from '@nextui-org/button';
import { useDisclosure } from '@nextui-org/use-disclosure';
import { useSnackbar } from 'notistack';
import { useEffect, useMemo } from 'react';
import { Address } from 'viem';
import { useAccount, useWaitForTransactionReceipt } from 'wagmi';
import { CouncilBadge } from './Badges';
import CouncilEligibilityModal from './CouncilEligibilityModal';
import VoteDelegation from './VoteDelegation';

import ENV from '@/config/environment';
import { useReadAxeMembershipIsMember } from '@/generated';
import { useCouncil } from '@/hooks/state/dao';

const CandidateActions: React.FC<{
  hasLootShares: boolean;
  isCandidate: boolean;
  isMember: boolean;
  resignPending: boolean;
  resignLoading: boolean;
  onResign: () => void;
  onEnlist: () => void;
}> = ({ hasLootShares, isCandidate, isMember, resignPending, resignLoading, onResign, onEnlist }) => {
  if (hasLootShares || isCandidate) {
    return (
      <>
        <div className="flex gap-2 sm:gap-4">
          <CouncilBadge isCouncil={hasLootShares} />
          <span>{hasLootShares ? 'Council Member' : 'Council Candidate'}</span>
        </div>
        {isCandidate && (
          <Button color="danger" variant="flat" onPress={onResign} isLoading={resignPending || resignLoading}>
            Resign as Candidate
          </Button>
        )}
        {isMember && <VoteDelegation />}
      </>
    );
  }

  return (
    <Button onPress={onEnlist} color="primary" className="w-full" isDisabled={!isMember}>
      {isMember ? 'Enlist as Candidate' : 'Become Eligible'}
    </Button>
  );
};

const CouncilMembership: React.FC = () => {
  const account = useAccount();
  const { isOpen, onOpen, onOpenChange, onClose } = useDisclosure();
  const { enqueueSnackbar } = useSnackbar();

  // Check if user is DAO member
  const { data: isMember = false } = useReadAxeMembershipIsMember({
    address: ENV.axeMembershipAddress,
    args: [account.address as Address],
  });

  // Check if user is council member or candidate
  const { balance: lootShares } = useLootShares();
  const { addresses: candidateAddresses, refresh } = useCandidates();
  const hasLootShares = useMemo(() => !!lootShares && lootShares > 0n, [lootShares]);
  const isCandidate = useMemo(
    () => !!account.address && candidateAddresses.includes(account.address),
    [account.address, candidateAddresses],
  );

  const {
    data: resignHash,
    isPending: resignPending,
    writeContract: resign,
  } = useWriteAxeMembershipResignAsCandidate();

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

  // Add button that uses the council hook
  const { canUpdate, requestUpdate, isUpdating: isUpdatePending } = useCouncil();

  return (
    <div className="flex flex-col w-full items-center">
      <div className="text-2xl mb-1 sm:mb-2">Council Membership</div>
      <div className="flex flex-col gap-2 sm:gap-4 w-full">
        <CandidateActions
          hasLootShares={hasLootShares}
          isCandidate={isCandidate}
          isMember={isMember}
          resignPending={resignPending}
          resignLoading={resignLoading}
          onResign={() => resign({ address: ENV.axeMembershipAddress })}
          onEnlist={onOpen}
        />
        <p className="text-sm text-gray-500">
          Every 24 hours, anyone can request for the council to be updated based on membership delegation.
        </p>
        <Button onClick={() => requestUpdate()} disabled={!canUpdate || isUpdatePending}>
          {isUpdatePending ? 'Updating...' : 'Update Council'}
        </Button>
        <CouncilEligibilityModal isOpen={isOpen} onOpenChange={onOpenChange} onClose={onClose} />
      </div>
    </div>
  );
};

export default CouncilMembership;
