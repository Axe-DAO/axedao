'use client';

import { Accordion, AccordionItem } from '@nextui-org/accordion';
import { Button } from '@nextui-org/button';
import { Modal, ModalBody, ModalContent, ModalHeader, ModalProps } from '@nextui-org/modal';
import { enqueueSnackbar } from 'notistack';
import { useEffect, useState } from 'react';
import { useWaitForTransactionReceipt } from 'wagmi';

import ENV from '@/config/environment';
import { useWriteAxeMembershipEnlistAsCandidate } from '@/generated';
import LootAcquisition from './LootAcquisition';

type Props = Omit<ModalProps, 'children'> & {
  hasLootShares: boolean;
};

const CouncilEligibilityModal: React.FC<Props> = ({ isOpen, onOpenChange, hasLootShares }: Props) => {
  const [isLootAcquisitionExpanded, setIsLootAcquisitionExpanded] = useState<boolean>(false);
  const {
    data: enlistHash,
    isPending: enlistPending,
    writeContract: enlist,
  } = useWriteAxeMembershipEnlistAsCandidate();

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
    enlist({ address: ENV.axeMembershipAddress });
  };

  return (
    <Modal isOpen={isOpen} onOpenChange={onOpenChange}>
      <ModalContent>
        {() => (
          <>
            <ModalHeader>Enlist as Council Candidate</ModalHeader>
            <ModalBody className="gap-3">
              <p>
                Council candidates can receive delegated votes from DAO members. The top candidates with the most
                delegations form the council.
              </p>

              {hasLootShares ? (
                <>
                  <p className="text-success">You have loot shares and are eligible to join the Council.</p>
                  <Button color="primary" onPress={handleEnlist} isLoading={enlistPending || enlistLoading}>
                    Enlist as Candidate
                  </Button>
                </>
              ) : (
                <>
                  <p className="text-warning">
                    You don&apos;t have any loot shares, yet. While not required to enlist as candidate, you need 1 loot
                    to claim a council seat if you receive enough delegated votes.
                  </p>
                  <Accordion
                    onExpandedChange={() => {
                      setIsLootAcquisitionExpanded(!isLootAcquisitionExpanded);
                    }}
                  >
                    <AccordionItem
                      key="loot-acquisition"
                      aria-label="Get Loot Shares"
                      title="Get Loot Shares (Optional)"
                    >
                      <div className="py-2">
                        <LootAcquisition
                          variant="compact"
                          onSuccess={() => {
                            // This will refresh the hasLootShares state
                            onOpenChange?.(false);
                          }}
                        />
                      </div>
                    </AccordionItem>
                  </Accordion>
                  <Button
                    color="primary"
                    onPress={handleEnlist}
                    isLoading={enlistPending || enlistLoading}
                    disabled={isLootAcquisitionExpanded}
                  >
                    Enlist as Candidate
                  </Button>
                </>
              )}
            </ModalBody>
          </>
        )}
      </ModalContent>
    </Modal>
  );
};

export default CouncilEligibilityModal;
