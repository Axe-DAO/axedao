'use client';

import { Table, TableBody, TableCell, TableColumn, TableHeader, TableRow } from '@nextui-org/table';
import { useAtomValue } from 'jotai';
import { useMemo } from 'react';

import UserCard from '@/components/UserCard';
import { candidatesAtom } from '@/hooks/state/dao';

export default function Candidates() {
  const candidates = useAtomValue(candidatesAtom);

  // Sort candidates by delegation count in descending order
  const sortedCandidates = useMemo(
    () => [...candidates].sort((a, b) => b.delegationCount - a.delegationCount),
    [candidates],
  );

  return (
    <div className="w-full flex flex-col gap-4">
      <div className="text-2xl">Council Candidates</div>
      <Table aria-label="Council candidates and their delegations">
        <TableHeader>
          <TableColumn>CANDIDATE</TableColumn>
          <TableColumn>DELEGATIONS</TableColumn>
        </TableHeader>
        <TableBody>
          {sortedCandidates.map((candidate) => (
            <TableRow key={candidate.walletAddress} className={!candidate.available ? 'opacity-50' : undefined}>
              <TableCell>
                <div className="flex items-center gap-2">
                  <UserCard user={candidate} />
                  {!candidate.available && <span className="text-sm text-gray-500">(Resigned)</span>}
                </div>
              </TableCell>
              <TableCell>{candidate.delegationCount}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
