'use client';

import { Button } from '@nextui-org/button';
import { Card, CardBody, CardHeader } from '@nextui-org/card';
import { useSnackbar } from 'notistack';
import { useEffect, useState } from 'react';
import { Address, formatUnits } from 'viem';
import { useAccount, useWaitForTransactionReceipt } from 'wagmi';

import ENV from '@/config/environment';
import {
  useReadErc20Allowance,
  useReadErc20BalanceOf,
  useReadTreasuryShamanConversionRate,
  useReadTreasuryShamanDepositToken,
  useWriteErc20Approve,
  useWriteTreasuryShamanDeposit,
} from '@/generated';

interface Props {
  onSuccess?: () => void;
  variant?: 'compact' | 'full';
}

export default function LootAcquisition({ onSuccess, variant = 'full' }: Props) {
  const { enqueueSnackbar } = useSnackbar();
  const account = useAccount();
  const [isApproved, setIsApproved] = useState(false);

  // Get deposit token info
  const { data: depositToken } = useReadTreasuryShamanDepositToken({
    address: ENV.daoTreasuryShamanAddress,
  });

  // Get conversion rate (1:1 by default)
  const { data: conversionRate } = useReadTreasuryShamanConversionRate({
    address: ENV.daoTreasuryShamanAddress,
  });

  // Get token balance and allowance
  const { data: tokenBalance } = useReadErc20BalanceOf({
    address: depositToken,
    args: [account.address as Address],
  });

  const { data: allowance, refetch: refetchAllowance } = useReadErc20Allowance({
    address: depositToken,
    args: [account.address as Address, ENV.daoTreasuryShamanAddress],
  });

  // Contract write hooks
  const { writeContract: approve, data: approveHash, isPending: isApprovePending } = useWriteErc20Approve();

  const {
    writeContract: deposit,
    data: depositHash,
    isPending: isDepositPending,
    error: depositWriteError,
  } = useWriteTreasuryShamanDeposit();

  // Calculate minimum deposit amount (1 loot)
  const minDepositAmount = conversionRate ? 1n * conversionRate : 0n;

  // Check if approved
  useEffect(() => {
    if (allowance && minDepositAmount) {
      setIsApproved(allowance >= minDepositAmount);
    }
  }, [allowance, minDepositAmount]);

  const handleApprove = async () => {
    if (!depositToken || !minDepositAmount) return;

    try {
      approve({
        address: depositToken,
        args: [ENV.daoTreasuryShamanAddress, minDepositAmount],
      });
    } catch (error) {
      console.error('Error approving tokens:', error);
      enqueueSnackbar('Failed to approve tokens', { variant: 'error' });
    }
  };

  const handleDeposit = async () => {
    if (!minDepositAmount) return;

    try {
      console.log('Attempting deposit with amount:', minDepositAmount.toString());
      console.log('Shaman address:', ENV.daoTreasuryShamanAddress);
      console.log('Deposit token:', depositToken);

      deposit({
        address: ENV.daoTreasuryShamanAddress,
        args: [minDepositAmount],
      });
    } catch (error) {
      console.error('Error depositing tokens:', error);
      enqueueSnackbar('Failed to deposit tokens', { variant: 'error' });
    }
  };

  // Add transaction receipt hooks after contract write hooks
  const {
    isSuccess: approveSuccess,
    error: approveError,
    isLoading: approveLoading,
  } = useWaitForTransactionReceipt({ hash: approveHash });

  const {
    isSuccess: depositSuccess,
    error: depositError,
    isLoading: depositLoading,
  } = useWaitForTransactionReceipt({ hash: depositHash });

  // Add effect for handling approve transaction states
  useEffect(() => {
    if (approveLoading) {
      enqueueSnackbar('Approving tokens. Please wait for confirmation...', {
        autoHideDuration: 3000,
      });
    } else if (approveSuccess) {
      enqueueSnackbar('Token approval confirmed!');
      refetchAllowance();
    } else if (approveError) {
      enqueueSnackbar(`Failed to approve: ${approveError.message}`, { variant: 'error' });
    }
  }, [approveLoading, approveSuccess, approveError, enqueueSnackbar, refetchAllowance]);

  // Add effect for handling deposit transaction states
  useEffect(() => {
    if (depositLoading) {
      enqueueSnackbar('Depositing tokens. Please wait for confirmation...', {
        autoHideDuration: 3000,
      });
    } else if (depositSuccess) {
      enqueueSnackbar('Successfully deposited tokens for loot!');
      onSuccess?.();
    } else if (depositError) {
      enqueueSnackbar(`Failed to deposit: ${depositError.message}`, { variant: 'error' });
    }
  }, [depositLoading, depositSuccess, depositError, enqueueSnackbar, onSuccess]);

  // Add effect to catch write errors
  useEffect(() => {
    if (depositWriteError) {
      console.error('Deposit write error:', depositWriteError);
      enqueueSnackbar(`Failed to initiate deposit: ${depositWriteError.message}`, { variant: 'error' });
    }
  }, [depositWriteError, enqueueSnackbar]);

  if (variant === 'compact') {
    return (
      <div className="flex flex-col gap-2">
        <p className="text-sm">Deposit {formatUnits(minDepositAmount, 18)} tokens to receive 1 loot</p>
        <Button
          color="primary"
          isDisabled={!tokenBalance || tokenBalance < minDepositAmount}
          isLoading={isApprovePending || approveLoading || isDepositPending || depositLoading}
          onPress={isApproved ? handleDeposit : handleApprove}
        >
          {isApproved ? 'Deposit' : 'Approve'}
        </Button>
      </div>
    );
  }

  return (
    <Card className="w-full">
      <CardHeader className="flex flex-col items-start px-4 pb-0 pt-4">
        <h4 className="text-large font-bold">Get Loot</h4>
        <p className="text-small text-default-500">Deposit tokens to receive loot shares</p>
      </CardHeader>
      <CardBody className="flex flex-col gap-4">
        <div className="flex flex-col gap-2">
          <div className="flex justify-between">
            <span>Minimum Deposit</span>
            <span>{formatUnits(minDepositAmount, 18)} tokens</span>
          </div>
          <div className="flex justify-between">
            <span>Your Balance</span>
            <span>{formatUnits(tokenBalance || 0n, 18)} tokens</span>
          </div>
          <div className="flex justify-between">
            <span>Conversion Rate</span>
            <span>1:{formatUnits(conversionRate || 1n * 10n ** 18n, 18)}</span>
          </div>
        </div>

        <Button
          color="primary"
          className="w-full"
          isDisabled={!tokenBalance || tokenBalance < minDepositAmount}
          isLoading={isApprovePending || approveLoading || isDepositPending || depositLoading}
          onPress={isApproved ? handleDeposit : handleApprove}
        >
          {isApproved ? 'Deposit for Loot' : 'Approve Tokens'}
        </Button>
      </CardBody>
    </Card>
  );
}
