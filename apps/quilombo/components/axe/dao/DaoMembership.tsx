'use client';

import { Button } from '@nextui-org/button';
import { useDisclosure } from '@nextui-org/use-disclosure';
import { Address } from 'viem';
import { useAccount } from 'wagmi';

import ENV from '@/config/environment';
import { useReadMembershipCouncilIsMember } from '@/generated';
import { MemberBadge } from './Badges';
import MembershipDonationModal from './MembershipDonationModal';

const DaoMembership: React.FC = () => {
  const account = useAccount();
  const { isOpen, onOpen, onOpenChange } = useDisclosure();

  const { data: isMember = false, refetch: updateIsMember } = useReadMembershipCouncilIsMember({
    address: ENV.axeMembershipAddress,
    args: [account.address as Address],
  });

  return (
    <div className="flex flex-col w-full items-center">
      <div className="text-2xl mb-1 sm:mb-2">Membership</div>
      <div className="flex flex-col gap-2 sm:gap-4 w-full">
        <MemberBadge isMember={isMember} />
        {isMember ? (
          <span>Thanks for being a member!</span>
        ) : (
          <div className="flex flex-col gap-2 sm:gap-4">
            <span>
              You&apos;re not a member.
              <br />
              Donate $10 once for lifetime membership.
            </span>
            <Button onPress={onOpen} color="primary" className="w-full">
              Join the DAO
            </Button>
          </div>
        )}
        <MembershipDonationModal isOpen={isOpen} onOpenChange={onOpenChange} onSuccess={updateIsMember} />
      </div>
    </div>
  );
};

export default DaoMembership;
