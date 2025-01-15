'use client';

import { Accordion, AccordionItem } from '@nextui-org/accordion';
import { Button } from '@nextui-org/button';
import { Modal, ModalBody, ModalContent, ModalHeader, ModalProps } from '@nextui-org/modal';
import { enqueueSnackbar } from 'notistack';
import { useEffect, useMemo, useState } from 'react';
import { useWaitForTransactionReceipt } from 'wagmi';

import ENV from '@/config/environment';
import { useWriteAxeMembershipEnlistAsCandidate } from '@/generated';
import { useLootShares } from '@/hooks/state/dao';
import LootAcquisition from './LootAcquisition';

type Props = Omit<ModalProps, 'children'>;

const CouncilEligibilityModal: React.FC<Props> = ({ isOpen, onClose, onOpenChange }: Props) => {
  const [isLootAcquisitionExpanded, setIsLootAcquisitionExpanded] = useState<boolean>(false);
  const { balance: lootShares, refetch: refetchLootShares } = useLootShares();
  const hasLootShares = useMemo(() => !!lootShares && lootShares > 0n, [lootShares]);

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
      onClose?.();
    } else if (enlistError) {
      enqueueSnackbar(`Failed to enlist: ${enlistError.message}`, { variant: 'error' });
    }
  }, [enlistLoading, enlistSuccess, enlistError, onClose]);

  const handleEnlist = () => {
    enlist({ address: ENV.axeMembershipAddress });
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} onOpenChange={onOpenChange}>
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
                        <LootAcquisition variant="compact" onSuccess={refetchLootShares} />
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
