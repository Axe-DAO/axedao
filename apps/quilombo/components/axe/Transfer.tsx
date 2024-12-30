'use client';

import { Button } from '@nextui-org/button';
import { useDisclosure } from '@nextui-org/modal';
import { Field, Form, Formik, FormikProps } from 'formik';
import { enqueueSnackbar } from 'notistack';
import { useEffect, useState } from 'react';
import { Address, formatUnits, parseUnits } from 'viem';
import { useAccount, useWaitForTransactionReceipt } from 'wagmi';

import ENV from '@/config/environment';
import { AxeTransferForm, axeTransferForm } from '@/config/validation-schema';
import { useReadErc20BalanceOf, useWriteErc20Transfer } from '@/generated';
import { User } from '@/types/model';
import ErrorText from '../ErrorText';
import { AmountInput, UserSelect } from '../forms';
import TransferConfirm from './TransferConfirm';

const Transfer: React.FC = () => {
  const account = useAccount();
  const [selectedRecipient, setSelectedRecipient] = useState<User | null>(null);
  const { isOpen, onOpen: openConfirmation, onOpenChange } = useDisclosure();

  const { data: axeBalance, refetch: updateAxeBalance } = useReadErc20BalanceOf({
    address: ENV.axeTokenAddress,
    args: [account.address as Address],
  });

  const { data: transferHash, isPending: transferPending, writeContract: transfer } = useWriteErc20Transfer();
  const {
    isSuccess: transferSuccess,
    error: transferError,
    isLoading: transferLoading,
  } = useWaitForTransactionReceipt({ hash: transferHash });

  // reactions to transfer receipt outcome
  useEffect(() => {
    if (transferLoading) {
      enqueueSnackbar('Axé transfer pending. Please allow some time to confirm ...', {
        autoHideDuration: 3000,
      });
    } else if (transferSuccess) {
      updateAxeBalance().then(() => enqueueSnackbar('Axé transfer confirmed!'));
    } else if (transferError) {
      enqueueSnackbar(`Axé transfer failed: ${transferError.message}`);
    }
  }, [transferLoading, transferSuccess, transferError, updateAxeBalance]);

  const initialValues: AxeTransferForm = {
    amount: '',
    to: '',
  };

  const handleSubmit = async ({ amount, to }: AxeTransferForm) => {
    try {
      const bigInput = parseUnits(amount, 18);
      // TODO check balance once more?
      transfer({ address: ENV.axeTokenAddress, args: [to as Address, bigInput] });
    } catch (error) {
      console.error('Error during transfer', error);
      throw error;
    }
  };

  return (
    <div className="inline-block w-full">
      <Formik<AxeTransferForm> initialValues={initialValues} validationSchema={axeTransferForm} onSubmit={handleSubmit}>
        {({ dirty, isValid, isSubmitting, submitForm, values }: FormikProps<AxeTransferForm>) => (
          <Form className="flex flex-col gap-3 sm:gap-5">
            <div className="flex flex-col gap-1">
              <Field
                name="amount"
                label="Amount"
                as={AmountInput}
                validate={(value: string) => {
                  if (parseUnits(value, 18) > (axeBalance || BigInt(0))) return 'Insufficient balance';
                }}
              />
              <div className="text-default-400 justify-end px-2">
                Available: {formatUnits(axeBalance || BigInt(0), 18)} Axé
              </div>
            </div>
            <Field
              name="to"
              label="Recipient"
              placeholder="Select a recipient"
              as={UserSelect}
              keyMode="walletAddress"
              onSelect={setSelectedRecipient}
            />
            <Button
              color="primary"
              size="lg"
              className="mt-4"
              isLoading={isSubmitting}
              disabled={!dirty || !isValid || transferPending}
              onPress={openConfirmation}
            >
              Send
            </Button>
            <ErrorText message={transferError?.message} />
            <TransferConfirm
              isOpen={isValid && isOpen}
              onOpenChange={onOpenChange}
              to={selectedRecipient}
              amount={values.amount}
              onConfirm={submitForm}
            />
          </Form>
        )}
      </Formik>
    </div>
  );
};

export default Transfer;
