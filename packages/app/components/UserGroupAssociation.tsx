'use client';

import { useAtomValue } from 'jotai';

import GroupCard from '@/components/GroupCard';
import { groupAtom } from '@/hooks/state/group';

const UserGroupAssociation = () => {
  const group = useAtomValue(groupAtom);
  return group ? (
    <GroupCard className="mx-auto sm:mx-0 md:max-w-80" group={group} />
  ) : (
    <div className="text-default-500 text-sm">User has no group association</div>
  );
};

export default UserGroupAssociation;
