'use client';

import { useAtomValue } from 'jotai';

import GroupCard from '@/components/GroupCard';
import { userProfileGroupAtom } from '@/hooks/state/user';

const UserGroupAssociation = () => {
  const group = useAtomValue(userProfileGroupAtom); // TODO this is likely wrong. This component is used on the UserProfile page
  return group ? (
    <GroupCard className="mx-auto sm:mx-0 md:max-w-80" group={group} />
  ) : (
    <div className="text-default-500 text-sm">User has no group association</div>
  );
};

export default UserGroupAssociation;
