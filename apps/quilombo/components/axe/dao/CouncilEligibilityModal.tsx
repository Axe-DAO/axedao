'use client';

import { Button } from '@nextui-org/button';
import { Modal, ModalBody, ModalContent, ModalFooter, ModalHeader, ModalProps } from '@nextui-org/modal';
import { enqueueSnackbar } from 'notistack';
import { useEffect } from 'react';
import { useWaitForTransactionReceipt } from 'wagmi';

import ENV from '@/config/environment';
import { useWriteMembershipCouncilEnlistAsCandidate } from '@/generated';

type Props = Omit<ModalProps, 'children'> & {
  hasLootShares: boolean;
};

const CouncilEligibilityModal: React.FC<Props> = ({ isOpen, onOpenChange, hasLootShares }: Props) => {
  const {
    data: enlistHash,
    isPending: enlistPending,
    writeContract: enlist,
  } = useWriteMembershipCouncilEnlistAsCandidate();

  const {
    isSuccess: enlistSuccess,
    error: enlistError,
    isLoading: enlistLoading,
  } = useWaitForTransactionReceipt({ hash: enlistHash });

  // Handle transaction states
  useEffect(() => {
    if (enlistLoading) {
      enqueueSnackbar('Enlisting as candidate. Please wait for confirmation...', {
        autoHideDuration: 3000,
      });
    } else if (enlistSuccess) {
      enqueueSnackbar('Successfully enlisted as candidate!');
      onOpenChange?.(false);
    } else if (enlistError) {
      enqueueSnackbar(`Failed to enlist: ${enlistError.message}`, { variant: 'error' });
      onOpenChange?.(false);
    }
  }, [enlistLoading, enlistSuccess, enlistError, onOpenChange]);

  const handleEnlist = () => {
    enlist({ address: ENV.membershipCouncilAddress });
  };

  return (
    <Modal isOpen={isOpen} onOpenChange={onOpenChange}>
      <ModalContent>
        {() => (
          <>
            <ModalHeader>Enlist as Council Candidate</ModalHeader>
            <ModalBody className="gap-3">
              <p>
                Council candidates can receive delegated votes from DAO members. The top candidates form the council.
              </p>
              {!hasLootShares && (
                <p>
                  Note: if eligible for a seat on the council, you will need to have 1 loot token to be converted to a
                  voting share. Get Loot here: (TODO)
                </p>
              )}
            </ModalBody>
            <ModalFooter>
              <Button color="primary" onPress={handleEnlist} isLoading={enlistPending || enlistLoading}>
                Enlist as Candidate
              </Button>
            </ModalFooter>
          </>
        )}
      </ModalContent>
    </Modal>
  );
};

export default CouncilEligibilityModal;
