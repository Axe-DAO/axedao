import { atom, useAtom } from 'jotai';
import { useEffect } from 'react';
import { PublicClient } from 'viem';
import { usePublicClient } from 'wagmi';

export const publicClientAtom = atom<PublicClient | null>(null);

export function useInitializePublicClient() {
  const [client, setPublicClient] = useAtom(publicClientAtom);
  const publicClient = usePublicClient();

  useEffect(() => {
    if (!client && publicClient) {
      setPublicClient(publicClient);
    }
  }, [client, setPublicClient, publicClient]);
}
