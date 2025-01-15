'use client';

import { Button } from '@nextui-org/button';
import { Modal, ModalBody, ModalContent, ModalFooter, ModalHeader, ModalProps } from '@nextui-org/modal';
import { atom, useAtom } from 'jotai';
import { enqueueSnackbar } from 'notistack';
import { useEffect } from 'react';
import { Address, formatEther, formatUnits } from 'viem';
import { useAccount, useBalance, useSendTransaction, useWaitForTransactionReceipt } from 'wagmi';

import ENV from '@/config/environment';
import {
  useReadAxeMembershipGetNativeDonationAmount,
  useReadAxeMembershipGetTokenDonationAmount,
  useReadErc20Allowance,
  useReadErc20BalanceOf,
  useWriteAxeMembershipDonate,
  useWriteErc20Approve,
} from '@/generated';

type Props = Omit<ModalProps, 'children'> & { onSuccess?: () => void };

const hasApprovalAtom = atom<boolean>(false);

export default function MembershipDonationModal({ onClose, onSuccess, ...props }: Props) {
  const account = useAccount();
  const [hasApproval, setHasApproval] = useAtom(hasApprovalAtom);

  // Get native token balance
  const { data: nativeBalance } = useBalance({
    address: account.address,
  });

  // Get ERC20 token balance
  const { data: erc20Balance } = useReadErc20BalanceOf({
    address: ENV.axeSwapTokenAddress,
    args: [account.address as Address],
  });

  // Get donation amounts from contract
  const { data: nativeDonationAmount } = useReadAxeMembershipGetNativeDonationAmount({
    address: ENV.axeMembershipAddress as Address,
  });
  const { data: erc20DonationAmount } = useReadAxeMembershipGetTokenDonationAmount({
    address: ENV.axeMembershipAddress as Address,
  });

  // For ERC20 Approve
  const { data: approveHash, isPending: approvePending, writeContract: approve } = useWriteErc20Approve();
  const {
    isSuccess: approveSuccess,
    error: approveError,
    isLoading: approveLoading,
  } = useWaitForTransactionReceipt({ hash: approveHash });

  // For IMembershipCouncil donate
  const { data: donateHash, isPending: donatePending, writeContract: donate } = useWriteAxeMembershipDonate();
  const {
    isSuccess: donateSuccess,
    error: donateError,
    isLoading: donateLoading,
  } = useWaitForTransactionReceipt({ hash: donateHash });

  // Sending native token
  const { data: sendHash, isPending: sendPending, sendTransaction: sendNative } = useSendTransaction();
  const {
    isSuccess: sendSuccess,
    error: sendError,
    isLoading: sendLoading,
  } = useWaitForTransactionReceipt({ hash: sendHash });

  const { data: allowanceAmount, refetch: updateAllowance } = useReadErc20Allowance({
    address: ENV.axeSwapTokenAddress,
    args: [account.address as Address, ENV.axeMembershipAddress],
  });

  // Update hasApproval state
  useEffect(() => {
    if (erc20DonationAmount && allowanceAmount) {
      const newApprovalState = allowanceAmount >= erc20DonationAmount;
      if (newApprovalState !== hasApproval) {
        setHasApproval(newApprovalState);
      }
    }
  }, [allowanceAmount, erc20DonationAmount, hasApproval, setHasApproval]);

  // Effect for approval result
  useEffect(() => {
    if (approveLoading) {
      enqueueSnackbar('Approval pending. Please allow some time to confirm ...', {
        autoHideDuration: 3000,
      });
    } else if (approveSuccess) {
      updateAllowance();
      enqueueSnackbar('Approval confirmed!');
    } else if (approveError) {
      enqueueSnackbar(`Approval failed: ${approveError.message}`);
    }
  }, [approveLoading, approveSuccess, approveError, updateAllowance]);

  // Effect for donation result
  useEffect(() => {
    if (donateLoading) {
      enqueueSnackbar('Donation pending. Please allow some time to confirm ...', {
        autoHideDuration: 3000,
      });
    } else if (donateSuccess) {
      enqueueSnackbar('Donation confirmed!');
      onSuccess?.();
      onClose?.();
    } else if (donateError) {
      enqueueSnackbar(`Donation failed: ${donateError.message}`);
    }
  }, [donateLoading, donateSuccess, donateError, onSuccess, onClose]);

  // Effect for send result
  useEffect(() => {
    if (sendLoading) {
      enqueueSnackbar('Send pending. Please allow some time to confirm ...', {
        autoHideDuration: 3000,
      });
    } else if (sendSuccess) {
      enqueueSnackbar('Send confirmed!');
      onSuccess?.();
      onClose?.();
    } else if (sendError) {
      enqueueSnackbar(`Send failed: ${sendError.message}`);
    }
  }, [sendLoading, sendSuccess, sendError, onSuccess, onClose]);

  const handleNativeDonation = async () => {
    if (!nativeDonationAmount) {
      console.warn('No native donation amount set. Unable to send.');
      return;
    }
    sendNative({
      to: ENV.axeMembershipAddress,
      value: nativeDonationAmount,
    });
  };

  const handleErc20Approval = async () => {
    if (!erc20DonationAmount) {
      console.warn('No token donation amount set. Unable to approve.');
      return;
    }
    approve({
      address: ENV.axeSwapTokenAddress,
      args: [ENV.axeMembershipAddress, erc20DonationAmount],
    });
  };

  const handleERC20Donation = async () => {
    donate({
      address: ENV.axeMembershipAddress,
    });
  };

  return (
    <Modal onClose={onClose} {...props} placement="center" hideCloseButton>
      <ModalContent>
        {(onClose) => (
          <>
            <ModalHeader className="flex flex-col gap-1">Choose Donation Method</ModalHeader>
            <ModalBody className="flex flex-col gap-4 pb-6">
              <div className="flex flex-col gap-4">
                {!hasApproval ? (
                  <Button
                    color="primary"
                    onClick={handleErc20Approval}
                    className="w-full"
                    disabled={!erc20Balance || (!!erc20DonationAmount && erc20DonationAmount > erc20Balance)}
                    isLoading={approvePending}
                  >
                    Approve {formatUnits(erc20DonationAmount ?? 0n, 18)} $USD
                  </Button>
                ) : (
                  <Button
                    color="primary"
                    onClick={handleERC20Donation}
                    className="w-full"
                    disabled={!erc20Balance || (!!erc20DonationAmount && erc20DonationAmount > erc20Balance)}
                    isLoading={donatePending}
                  >
                    Donate {formatUnits(erc20DonationAmount ?? 0n, 18)} $USD
                  </Button>
                )}
                <div className="text-small text-default-500 text-center">
                  Balance: {erc20Balance ? formatUnits(erc20Balance, 18) : '0'} $USD
                </div>

                <Button
                  color="primary"
                  onClick={handleNativeDonation}
                  className="w-full"
                  disabled={!nativeBalance || (!!nativeDonationAmount && nativeDonationAmount > nativeBalance.value)}
                  isLoading={sendPending}
                >
                  Donate {formatEther(nativeDonationAmount ?? 0n)} {nativeBalance?.symbol || 'ETH'}
                </Button>

                <div className="text-small text-default-500 text-center">
                  Balance: {nativeBalance ? formatEther(nativeBalance.value) : '0'} {nativeBalance?.symbol || 'ETH'}
                </div>
              </div>
            </ModalBody>
            <ModalFooter>
              <Button variant="light" color="danger" onPress={onClose} className="w-full">
                Cancel
              </Button>
            </ModalFooter>
          </>
        )}
      </ModalContent>
    </Modal>
  );
}
