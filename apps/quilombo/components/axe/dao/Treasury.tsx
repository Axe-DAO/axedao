'use client';

import { Card, CardBody } from '@nextui-org/card';
import { Table, TableBody, TableCell, TableColumn, TableHeader, TableRow } from '@nextui-org/table';
import { format } from 'dnum';

import ENV from '@/config/environment';
import { useReadErc20BalanceOf } from '@/generated';

const Treasury: React.FC = () => {
  const { data: axeSafe } = useReadErc20BalanceOf({
    address: ENV.axeTokenAddress,
    args: [ENV.axeTreasuryAddress],
  });

  const { data: usdSafe } = useReadErc20BalanceOf({
    address: ENV.axeSwapTokenAddress,
    args: [ENV.axeTreasuryAddress],
  });

  const { data: usdDao } = useReadErc20BalanceOf({
    address: ENV.axeSwapTokenAddress,
    args: [ENV.daoTreasuryAddress],
  });

  return (
    <Card className="inline-block w-full items-center" title="Community Treasury">
      <CardBody className="flex flex-col gap-1 sm:gap-2">
        <h2 className="text-bold text-center">Community Treasury</h2>
        <Table aria-label="Community Treasury" classNames={{ wrapper: 'border border-gray-500 m-0 p-0' }}>
          <TableHeader>
            <TableColumn>Asset</TableColumn>
            <TableColumn align="end">Amount</TableColumn>
          </TableHeader>
          <TableBody>
            <TableRow key="usd">
              <TableCell>USD</TableCell>
              <TableCell>$ {format([usdDao || BigInt(0), 18], { digits: 2, trailingZeros: true })}</TableCell>
            </TableRow>
          </TableBody>
        </Table>
        <h2 className="text-bold text-center mt-3">Axé Safe</h2>
        <Table aria-label="Axé Treasury" classNames={{ wrapper: 'border border-gray-500 m-0 p-0' }}>
          <TableHeader>
            <TableColumn>Asset</TableColumn>
            <TableColumn align="end">Amount</TableColumn>
          </TableHeader>
          <TableBody>
            <TableRow key="axe">
              <TableCell>Axé</TableCell>
              <TableCell>{format([axeSafe || BigInt(0), 18], { digits: 2, trailingZeros: true })}</TableCell>
            </TableRow>
            <TableRow key="usd">
              <TableCell>USD</TableCell>
              <TableCell>$ {format([usdSafe || BigInt(0), 18], { digits: 2, trailingZeros: true })}</TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </CardBody>
    </Card>
  );
};

export default Treasury;
