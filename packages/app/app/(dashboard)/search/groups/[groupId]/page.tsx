import { dehydrate, HydrationBoundary } from '@tanstack/react-query';
import { notFound } from 'next/navigation';

import { GroupProfileClientState } from '@/components/GroupProfile';
import GroupView from '@/components/GroupProfile/GroupView';
import { fetchGroup, fetchGroupAdminIds, fetchGroupMembers } from '@/db';
import { QUERY_KEYS } from '@/query';
import { createDefaultQueryClient } from '@/utils';

type Props = { params: { groupId: string } };

const GroupProfilePage = async ({ params: { groupId } }: Props) => {
  if (!groupId) throw Error('This page must be placed on a dynamic path containing [groupId]');
  const group = await fetchGroup(groupId);
  const adminIds = await fetchGroupAdminIds(groupId);
  const groupMembers = await fetchGroupMembers(groupId);
  if (!group) throw notFound();

  const queryClient = createDefaultQueryClient();
  queryClient.setQueryData([QUERY_KEYS.group.getGroup, groupId], group);
  queryClient.setQueryData([QUERY_KEYS.group.getGroupAdmins], adminIds);
  queryClient.setQueryData([QUERY_KEYS.group.getGroupMembers], groupMembers);
  const dehydratedState = dehydrate(queryClient);
  queryClient.clear(); // should help with memory usage

  return (
    <HydrationBoundary state={dehydratedState}>
      <GroupProfileClientState groupId={groupId}>
        <GroupView />
      </GroupProfileClientState>
    </HydrationBoundary>
  );
};

export default GroupProfilePage;
