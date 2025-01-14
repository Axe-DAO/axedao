'use client';

import { Button } from '@nextui-org/button';
import { useSnackbar } from 'notistack';
import { useEffect, useState } from 'react';
import { Address } from 'viem';
import { useAccount, useWaitForTransactionReceipt } from 'wagmi';

import DelegateForm from '@/components/forms/DelegateForm';
import UserCard from '@/components/UserCard';
import ENV from '@/config/environment';
import { MembershipDelegateForm } from '@/config/validation-schema';
import {
  useReadMembershipCouncilDelegations,
  useWriteMembershipCouncilDelegate,
  useWriteMembershipCouncilUndelegate,
} from '@/generated';
import { useCandidates } from '@/hooks/state/dao';
import { User } from '@/types/model';

const VoteDelegation: React.FC = () => {
  const account = useAccount();
  const { enqueueSnackbar } = useSnackbar();
  const [showDelegateForm, setShowDelegateForm] = useState(false);
  const [selectedCandidate, setSelectedCandidate] = useState<User | null>(null);
  const { candidates } = useCandidates();

  // Read current delegation
  const { data: currentDelegationAddress, refetch: refetchCurrentDelegation } = useReadMembershipCouncilDelegations({
    address: ENV.membershipCouncilAddress,
    args: [account.address as Address],
  });

  // Contract interaction hooks
  const {
    data: delegateHash,
    isPending: delegatePending,
    writeContract: delegate,
  } = useWriteMembershipCouncilDelegate();

  const {
    data: undelegateHash,
    isPending: undelegatePending,
    writeContract: undelegate,
  } = useWriteMembershipCouncilUndelegate();

  // Transaction receipt hooks
  const {
    isSuccess: delegateSuccess,
    error: delegateError,
    isLoading: delegateLoading,
  } = useWaitForTransactionReceipt({ hash: delegateHash });

  const {
    isSuccess: undelegateSuccess,
    error: undelegateError,
    isLoading: undelegateLoading,
  } = useWaitForTransactionReceipt({ hash: undelegateHash });

  // Handle transaction states
  useEffect(() => {
    if (delegateLoading) {
      enqueueSnackbar('Delegating vote. Please wait for confirmation...', { autoHideDuration: 3000 });
    } else if (delegateSuccess) {
      enqueueSnackbar('Successfully delegated vote!');
      setShowDelegateForm(false);
      refetchCurrentDelegation();
    } else if (delegateError) {
      enqueueSnackbar(`Failed to delegate: ${delegateError.message}`, { variant: 'error' });
    }
  }, [delegateLoading, delegateSuccess, delegateError, enqueueSnackbar, refetchCurrentDelegation]);

  useEffect(() => {
    if (undelegateLoading) {
      enqueueSnackbar('Removing delegation. Please wait for confirmation...', { autoHideDuration: 3000 });
    } else if (undelegateSuccess) {
      enqueueSnackbar('Successfully removed delegation!');
      refetchCurrentDelegation();
    } else if (undelegateError) {
      enqueueSnackbar(`Failed to undelegate: ${undelegateError.message}`, { variant: 'error' });
    }
  }, [undelegateLoading, undelegateSuccess, undelegateError, enqueueSnackbar, refetchCurrentDelegation]);

  useEffect(() => {
    if (currentDelegationAddress === selectedCandidate?.walletAddress) return;
    let newSelection: User | undefined = undefined;
    if (currentDelegationAddress) {
      newSelection = candidates?.find((candidate) => candidate.walletAddress === currentDelegationAddress);
    }
    setSelectedCandidate(newSelection || null);
  }, [currentDelegationAddress, selectedCandidate, candidates]);

  const handleSubmit = async (values: MembershipDelegateForm) => {
    await delegate({
      address: ENV.membershipCouncilAddress,
      args: [values.candidate as Address],
    });
  };

  const handleUndelegate = () => {
    undelegate({ address: ENV.membershipCouncilAddress });
  };

  const hasActiveDelegation =
    currentDelegationAddress && currentDelegationAddress !== '0x0000000000000000000000000000000000000000';

  return (
    <div className="flex flex-col gap-2">
      <h3 className="text-lg">Vote Delegation</h3>
      {hasActiveDelegation ? (
        !showDelegateForm ? (
          <div className="flex flex-col gap-2">
            {selectedCandidate && <UserCard user={selectedCandidate} />}
            <div className="flex gap-2">
              <Button variant="flat" onPress={() => setShowDelegateForm(true)}>
                Change
              </Button>
              <Button
                color="danger"
                variant="flat"
                onPress={handleUndelegate}
                isLoading={undelegatePending || undelegateLoading}
              >
                Undelegate
              </Button>
            </div>
          </div>
        ) : (
          <DelegateForm
            onSubmit={handleSubmit}
            onCancel={() => setShowDelegateForm(false)}
            isLoading={delegatePending || delegateLoading}
            candidates={candidates ?? []}
            currentDelegationAddress={currentDelegationAddress}
          />
        )
      ) : !showDelegateForm ? (
        <Button color="primary" onPress={() => setShowDelegateForm(true)}>
          Delegate
        </Button>
      ) : (
        <DelegateForm
          onSubmit={handleSubmit}
          onCancel={() => setShowDelegateForm(false)}
          isLoading={delegatePending || delegateLoading}
          candidates={candidates ?? []}
          currentDelegationAddress={currentDelegationAddress}
        />
      )}
    </div>
  );
};

export default VoteDelegation;
