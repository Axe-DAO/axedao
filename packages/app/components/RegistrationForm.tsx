'use client';

import { Button } from '@nextui-org/button';
import { Input } from '@nextui-org/input';
import { AxiosError } from 'axios';
import { Field, FieldInputProps, FieldMetaProps, Form, Formik, FormikHelpers, FormikProps } from 'formik';
import { useSession } from 'next-auth/react';
import { useEffect } from 'react';
import { useAccount, useConnect } from 'wagmi';
import { injected } from 'wagmi/connectors';

import { registrationFormSchema, RegistrationFormType } from '@/constants/schemas';
import useRegister from '@/hooks/useRegister';

const RegistrationForm = () => {
  const session = useSession();
  const { connect } = useConnect();
  const { registrationMutation } = useRegister();
  const isSubmitting = registrationMutation.isPending;
  const isLoading = session.status === 'loading';
  const submitError: AxiosError | Error | null = registrationMutation.error;

  const FormikForm = ({ setFieldValue, dirty, isValid }: FormikProps<RegistrationFormType>) => {
    const { address, isConnected } = useAccount();
    useEffect(() => {
      setFieldValue('walletAddress', address || '');
    }, [address, isConnected, setFieldValue]);

          return (
      <Form className="m-auto flex h-fit w-full max-w-sm flex-col gap-3">
        <Field name="name">
          {({ field, meta }: { field: FieldInputProps<string>; meta: FieldMetaProps<string> }) => (
            <Input
              {...field}
              label="Nickname"
              className="w-full"
              classNames={{ inputWrapper: '!min-h-14', errorMessage: 'text-left' }}
              color={meta.touched && meta.error ? 'danger' : undefined}
              isInvalid={!!meta.error}
              errorMessage={meta.touched && meta.error ? meta.error : undefined}
            />
          )}
        </Field>
        <Field name="email">
          {({ field, meta }: { field: FieldInputProps<string>; meta: FieldMetaProps<string> }) => (
            <Input
              {...field}
              type="email"
              label="Email"
              className="w-full"
              classNames={{ inputWrapper: '!min-h-14', errorMessage: 'text-left' }}
              color={meta.touched && meta.error ? 'danger' : undefined}
              isInvalid={!!meta.error}
              errorMessage={meta.touched && meta.error ? meta.error : undefined}
            />
          )}
        </Field>

      <div className="flex flex-col items-end">
          <Field name="walletAddress">
            {({ field, meta }: { field: FieldInputProps<string>; meta: FieldMetaProps<string> }) => (
              <Input
                {...field}
                label="Wallet address (MetaMask)"
                className="w-full"
                classNames={{
                  inputWrapper: '!min-h-14 data-[hover=true]:bg-initial',
                  input: 'text-sm !text-default-500',
                  errorMessage: 'text-left',
                }}
                color={meta.touched && meta.error ? 'danger' : undefined}
                isInvalid={!!meta.error}
                errorMessage={meta.touched && meta.error ? meta.error : undefined}
                placeholder={!meta.value ? 'No wallet connected' : undefined}
                readOnly
              />
            )}
          </Field>
        <Button
          size="sm"
          variant="ghost"
          className="ml-auto w-fit mt-2"
          onPress={() => connect({ connector: injected() })}
        >
            {address ? 'Change' : 'Connect'}
        </Button>
      </div>
      {submitError && (
        <div className="my-2 text-center text-small text-danger">
          {(submitError as AxiosError<{ error: string }>).response?.data?.error || submitError.message}
        </div>
      )}
      <Button
        key="register-button"
        type="submit"
        color="primary"
        className="mt-5 w-full"
        isLoading={isSubmitting}
          disabled={isLoading || isSubmitting || !dirty || !isValid}
      >
        Register
      </Button>
      </Form>
    );
  };

  const handleSubmit = (values: RegistrationFormType, { setSubmitting }: FormikHelpers<RegistrationFormType>) => {
    try {
      registrationMutation.mutate(values);
    } catch (error) {
      console.error('Error during registration.', error);
      throw error;
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Formik<RegistrationFormType>
      initialValues={{
        name: '',
        email: '',
        walletAddress: '',
      }}
      onSubmit={handleSubmit}
      validationSchema={registrationFormSchema}
    >
      {(props) => FormikForm(props)}
    </Formik>
  );
};

export default RegistrationForm;
