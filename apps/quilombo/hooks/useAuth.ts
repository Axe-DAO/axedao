import { useSetAtom } from 'jotai';
import { getCsrfToken, getSession, signIn as nextAuthSignIn, signOut as nextAuthSignOut } from 'next-auth/react';
import { useSearchParams } from 'next/navigation';
import { useEffect, useState } from 'react';
import { SiweMessage } from 'siwe';
import { UserRejectedRequestError } from 'viem';
import { useAccount, useConnect, useDisconnect, useSignMessage } from 'wagmi';

import { PATHS } from '@/config/constants';
import { getDefaultChain, silkInitOptions } from '@/config/wagmi';
import silk from '@/utils/silk.connector';
import { setCookie } from 'cookies-next';
import { enqueueSnackbar } from 'notistack';
import { triggerCurrentUserIdAtom } from './state/currentUser';

/**
 * Handles wagmi connect, signMessage, and logout using the Silk wallet.
 * Only a single 'loading' and 'error' field are stored in state and used across
 * all functions.
 * @returns
 */
const useSignIn = () => {
  const [state, setState] = useState<{
    loading?: boolean;
    nonce?: string;
    error?: Error;
  }>({});
  const setCurrentUserId = useSetAtom(triggerCurrentUserIdAtom);
  const { address, chainId } = useAccount();
  const { connect: wagmiConnect, error: connectError, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const { signMessageAsync } = useSignMessage();
  const params = useSearchParams();
  const callbackUrl = params.get('callbackUrl') || PATHS.profile;

  const fetchNonce = async () => {
    try {
      const nonce = await getCsrfToken();
      setState((x) => ({ ...x, nonce }));
    } catch (error) {
      setState((x) => ({ ...x, error: error as Error }));
    }
  };

  // Pre-fetch random nonce when component using the hook is rendered
  useEffect(() => {
    fetchNonce();
  }, []);

  const signIn = async () => {
    try {
      if (!address || !chainId) return;

      setState((x) => ({ ...x, loading: true, error: undefined }));
      // Create SIWE message with pre-fetched nonce and sign with wallet
      const message = new SiweMessage({
        domain: window.location.host,
        address,
        statement: 'Quilombo Login - Please sign this message to log in to the app.',
        uri: window.location.origin,
        version: '1',
        chainId,
        nonce: state.nonce,
      });

      const signature = await signMessageAsync({
        message: message.prepareMessage(),
      });

      const res = await nextAuthSignIn('credentials', {
        message: JSON.stringify(message),
        signature,
        callbackUrl,
      });

      if (res?.ok && !res.error) {
        const session = await getSession();
        console.info('User signed in:', session?.user?.id);
        setCurrentUserId(session?.user?.id);
      } else if (res?.error) {
        const msg = `An error occurred while signin in. Code: ${res.status} - ${res.error}`;
        console.error(msg);
        setState((x) => ({ ...x, error: new Error(res.error || 'Unable to authenticate the message') }));
      }

      setState((x) => ({ ...x, loading: false }));
    } catch (error) {
      setState((x) => ({ ...x, loading: false, error: error as Error, nonce: undefined }));
      fetchNonce();
    }
  };

  const logout = async () => {
    return nextAuthSignOut().then(() => {
      disconnect();
      setCurrentUserId(undefined);
      // remove the skipOnboarding flag, so the user sees the onboarding modal again
      setCookie('quilombo.skipOnboarding', false);
      setState({});
    });
  };

  const connect = async () => {
    setState((x) => ({ ...x, loading: true, error: undefined }));
    const silkConnector = connectors.find((connector) => connector.id === 'silk');
    const defaultChain = getDefaultChain();
    try {
      // There should already be a silk connector in the wagmi config which also
      // enables automatic reconnect on page refresh, but just in case, we can also create
      // the connector here.
      if (!silkConnector) {
        wagmiConnect({
          // TODO referral code ENV var
          chainId: defaultChain.id,
          connector: silk(silkInitOptions),
        });
      } else {
        wagmiConnect({ chainId: defaultChain.id, connector: silkConnector });
      }
      setState((x) => ({ ...x, loading: false }));
    } catch (error) {
      console.error('Error connecting to Silk:', error);
      if (error instanceof UserRejectedRequestError)
        enqueueSnackbar('Operation cancelled by user.', { variant: 'info' });
      else setState((x) => ({ ...x, loading: false, error: error as Error }));
    }
  };

  return { signIn, logout, connect, connectError, state };
};

export default useSignIn;
