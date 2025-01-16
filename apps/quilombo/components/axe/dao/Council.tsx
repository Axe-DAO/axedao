'use client';

import { Button } from '@nextui-org/button';
import { Table, TableBody, TableCell, TableColumn, TableHeader, TableRow } from '@nextui-org/table';
import { useSnackbar } from 'notistack';
import { useEffect } from 'react';
import { useWaitForTransactionReceipt } from 'wagmi';

import UserCard from '@/components/UserCard';
import { useCouncil } from '@/hooks/state/dao';

export default function Council() {
  const { enqueueSnackbar } = useSnackbar();
  const { members, isLoading, error, canUpdate, requestUpdate, isUpdating: isUpdatePending, updateHash } = useCouncil();

  const {
    isSuccess: updateSuccess,
    error: updateError,
    isLoading: updateLoading,
  } = useWaitForTransactionReceipt({ hash: updateHash });

  // Handle update transaction states
  useEffect(() => {
    if (updateLoading) {
      enqueueSnackbar('Requesting council update...', { autoHideDuration: 3000 });
    } else if (updateSuccess) {
      enqueueSnackbar('Council update requested successfully!');
    } else if (updateError) {
      enqueueSnackbar(`Failed to request update: ${updateError.message}`, { variant: 'error' });
    }
  }, [updateLoading, updateSuccess, updateError, enqueueSnackbar]);

  if (isLoading) {
    return <div>Loading council...</div>;
  }

  if (error) {
    return <div className="text-danger">Error: {error}</div>;
  }

  return (
    <div className="w-full flex flex-col gap-4">
      <div className="flex justify-end">
        <Button
          color="primary"
          isDisabled={!canUpdate}
          isLoading={isUpdatePending || updateLoading}
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
    </div>
  );
}
