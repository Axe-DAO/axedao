'use client';

import { Button } from '@nextui-org/button';
import { useDisclosure } from '@nextui-org/use-disclosure';
import { Address } from 'viem';
import { useAccount } from 'wagmi';

import ENV from '@/config/environment';
import { useReadMembershipCouncilIsMember } from '@/generated';
import { useCandidates, useHasVotingShares } from '@/hooks/state/dao';
import { CouncilBadge } from './Badges';
import CouncilEligibilityModal from './CouncilEligibilityModal';

const CouncilMembership: React.FC = () => {
  const account = useAccount();
  const { isOpen, onOpen, onOpenChange } = useDisclosure();

  // Check if user is DAO member
  const { data: isMember = false } = useReadMembershipCouncilIsMember({
    address: ENV.membershipCouncilAddress,
    args: [account.address as Address],
  });

  // Check if user is council member or candidate
  const hasVotingShares = useHasVotingShares();
  const { addresses: candidateAddresses } = useCandidates();
  const isCandidate = !!account.address && candidateAddresses.includes(account.address);

  // Don't show button if already candidate or council member
  if (hasVotingShares || isCandidate) {
    return (
      <div className="flex flex-col gap-2 sm:gap-4 w-full">
        <div className="flex gap-2 sm:gap-4">
          <CouncilBadge isCouncil={hasVotingShares} />
          <span>{hasVotingShares ? 'Council Member' : 'Council Candidate'}</span>
        </div>
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
        <CouncilEligibilityModal isOpen={isOpen} onOpenChange={onOpenChange} hasVotingShares={hasVotingShares} />
      </div>
    </div>
  );
};

export default CouncilMembership;
