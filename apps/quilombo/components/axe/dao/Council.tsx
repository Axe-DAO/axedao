'use client';

import { Button } from '@nextui-org/button';
import { Table, TableBody, TableCell, TableColumn, TableHeader, TableRow } from '@nextui-org/table';

import UserCard from '@/components/UserCard';
import { useCouncil, useCouncilUpdateRequest, useIncomingCouncil, useOutgoingCouncil } from '@/hooks/state/dao';

export default function Council() {
  const { members, isLoading, error, canUpdate } = useCouncil();
  const { incoming } = useIncomingCouncil();
  const { outgoing } = useOutgoingCouncil();
  const { requestUpdate, isPending: isUpdatePending } = useCouncilUpdateRequest();

  if (isLoading) {
    return <div>Loading council...</div>;
  }

  if (error) {
    return <div className="text-danger">Error: {error}</div>;
  }

  return (
    <div className="w-full flex flex-col gap-4">
      <div className="flex justify-between">
        <p className="text-sm text-gray-500">
          Every 24 hours, anyone can request for the council to be updated based on membership delegation.
        </p>
        <Button
          color="primary"
          isDisabled={!canUpdate || isLoading}
          isLoading={isUpdatePending}
          onPress={() => requestUpdate()}
        >
          Request Council Update
        </Button>
      </div>

      <Table aria-label="Current Council Members">
        <TableHeader>
          <TableColumn>MEMBER</TableColumn>
          <TableColumn>DELEGATIONS</TableColumn>
        </TableHeader>
        <TableBody isLoading={isLoading}>
          {members.map((member) => (
            <TableRow key={member.id}>
              <TableCell>
                <UserCard user={member} />
              </TableCell>
              <TableCell>{member.delegationCount}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
      <div className="flex flex-col gap-4">
        <h2>Incoming</h2>
        <Table>
          <TableHeader>
            <TableColumn>MEMBER</TableColumn>
          </TableHeader>
          <TableBody>
            {incoming.map((member) => (
              <TableRow key={member.id}>
                <TableCell>
                  <UserCard user={member} />
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
        <Table aria-label="Outgoing Council Members">
          <TableHeader>
            <TableColumn>MEMBER</TableColumn>
          </TableHeader>
          <TableBody>
            {outgoing.map((member) => (
              <TableRow key={member.id}>
                <TableCell>
                  <UserCard user={member} />
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
