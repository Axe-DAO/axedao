'use client';

import { Modal, ModalBody, ModalContent, ModalHeader } from '@nextui-org/modal';

interface Props {
  isOpen: boolean;
  onOpenChange: () => void;
  hasVotingShares: boolean;
}

const CouncilEligibilityModal: React.FC<Props> = ({ isOpen, onOpenChange, hasVotingShares }) => {
  return (
    <Modal isOpen={isOpen} onOpenChange={onOpenChange}>
      <ModalContent>
        {() => (
          <>
            <ModalHeader>{hasVotingShares ? 'Enlist as Council Candidate' : 'Become Eligible'}</ModalHeader>
            <ModalBody>
              {/* Content will be implemented later */}
              <p>Modal content coming soon...</p>
            </ModalBody>
          </>
        )}
      </ModalContent>
    </Modal>
  );
};

export default CouncilEligibilityModal;
