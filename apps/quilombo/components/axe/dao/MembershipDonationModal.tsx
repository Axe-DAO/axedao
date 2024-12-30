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
  useReadErc20Allowance,
  useReadErc20BalanceOf,
  useReadMembershipCouncilGetNativeDonationAmount,
  useReadMembershipCouncilGetTokenDonationAmount,
  useWriteErc20Approve,
  useWriteIMembershipCouncilDonate,
} from '@/generated';

type Props = Omit<ModalProps, 'children'>;

export default function MembershipDonationModal({ onClose, ...props }: Props) {
  const account = useAccount();
  const [hasApproval, setHasApproval] = useAtom(atom<boolean>(false));

  // Get native token balance
  const { data: nativeBalance, refetch: updateNativeBalance } = useBalance({
    address: account.address,
  });

  // Get ERC20 token balance
  const { data: erc20Balance, refetch: updateErc20Balance } = useReadErc20BalanceOf({
    address: ENV.axeSwapTokenAddress,
    args: [account.address as Address],
  });

  // Get donation amounts from contract
  const { data: nativeDonationAmount } = useReadMembershipCouncilGetNativeDonationAmount({
    address: ENV.membershipCouncilAddress as Address,
  });
  const { data: erc20DonationAmount } = useReadMembershipCouncilGetTokenDonationAmount({
    address: ENV.membershipCouncilAddress as Address,
  });

  // For ERC20 Approve
  const { data: approveHash, isPending: approvePending, writeContract: approve } = useWriteErc20Approve();
  const {
    isSuccess: approveSuccess,
    error: approveError,
    isLoading: approveLoading,
  } = useWaitForTransactionReceipt({ hash: approveHash });

  // For IMembershipCouncil donate
  const { data: donateHash, isPending: donatePending, writeContract: donate } = useWriteIMembershipCouncilDonate();
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
    args: [account.address as Address, ENV.membershipCouncilAddress],
  });

  useEffect(() => {
    if (erc20DonationAmount && allowanceAmount) {
      setHasApproval(allowanceAmount >= erc20DonationAmount);
    }
  }, [allowanceAmount, erc20DonationAmount, setHasApproval]);

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
      updateErc20Balance();
      enqueueSnackbar('Donation confirmed!');
    } else if (donateError) {
      enqueueSnackbar(`Donation failed: ${donateError.message}`);
    }
  }, [donateLoading, donateSuccess, donateError, updateErc20Balance]);

  // Effect for send result
  useEffect(() => {
    if (sendLoading) {
      enqueueSnackbar('Send pending. Please allow some time to confirm ...', {
        autoHideDuration: 3000,
      });
    } else if (sendSuccess) {
      updateNativeBalance();
      enqueueSnackbar('Send confirmed!');
    } else if (sendError) {
      enqueueSnackbar(`Send failed: ${sendError.message}`);
    }
  }, [sendLoading, sendSuccess, sendError, updateNativeBalance]);

  const handleNativeDonation = async () => {
    if (!nativeDonationAmount) {
      console.warn('No native donation amount set. Unable to send.');
      return;
    }
    sendNative({
      to: ENV.membershipCouncilAddress,
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
      args: [ENV.membershipCouncilAddress, erc20DonationAmount],
    });
  };

  const handleERC20Donation = async () => {
    donate({
      address: ENV.membershipCouncilAddress,
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
