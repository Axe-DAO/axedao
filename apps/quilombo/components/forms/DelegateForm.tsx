'use client';

import { Button } from '@nextui-org/button';
import { Field, Form, Formik } from 'formik';
import { Address } from 'viem';

import { MembershipDelegateForm, membershipDelegateSchema } from '@/config/validation-schema';
import { User } from '@/types/model';
import UserSelect from './UserSelect';

interface Props {
  onSubmit: (values: MembershipDelegateForm) => Promise<void>;
  onCancel: () => void;
  isLoading?: boolean;
  candidates: User[];
  currentDelegationAddress?: Address;
}

const DelegateForm: React.FC<Props> = ({
  onSubmit,
  onCancel,
  isLoading,
  candidates,
  currentDelegationAddress,
}) => {
  if (!candidates.length) {
    return (
      <div className="flex flex-col gap-2">
        <p className="text-warning">No candidates available for delegation.</p>
        <div className="flex justify-end">
          <Button variant="flat" onPress={onCancel}>
            Cancel
          </Button>
        </div>
      </div>
    );
  }

  return (
    <Formik<MembershipDelegateForm>
      initialValues={{ candidate: currentDelegationAddress || '' }}
      validationSchema={membershipDelegateSchema}
      onSubmit={onSubmit}
    >
      {({ isValid, dirty, values }) => (
        <Form className="flex flex-col gap-2">
          <Field
            name="candidate"
            keyMode="walletAddress"
            as={UserSelect}
            users={candidates}
            label="Select a candidate"
          />
          <div className="flex gap-2 justify-end">
            <Button variant="flat" onPress={onCancel}>
              Cancel
            </Button>
            <Button
              type="submit"
              color="primary"
              isDisabled={!isValid || !dirty || values.candidate === currentDelegationAddress}
              isLoading={isLoading}
            >
              Confirm
            </Button>
          </div>
        </Form>
      )}
    </Formik>
  );
};

export default DelegateForm;
