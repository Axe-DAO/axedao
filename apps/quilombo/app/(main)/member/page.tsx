'use client';

import { Button } from '@nextui-org/button';
import { parseEther } from 'viem';
import {
  type BaseError,
  useAccount,
  useChainId,
  useSendTransaction,
  useSwitchChain,
  useWaitForTransactionReceipt,
} from 'wagmi';

const MOCK_NFT_ADDRESS = '0x14739983a94fc5664638f3f74ca0bc820906d9e8';
const MINT_PRICE = parseEther('0.01');

const NFTPage = () => {
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();
  const { isConnected } = useAccount();

  const { data: hash, isPending, sendTransaction } = useSendTransaction();
  const {
    isLoading: isConfirming,
    isSuccess: isConfirmed,
    error,
  } = useWaitForTransactionReceipt({
    hash,
  });

  const handleChainSwitch = () => {
    if (chainId === 100) {
      // If on Gnosis
      switchChain({ chainId: 11155111 }); // Switch to Sepolia
    } else {
      switchChain({ chainId: 100 }); // Switch to Gnosis
    }
  };

  const handleMint = () => {
    if (!isConnected) {
      alert('Please connect your wallet first');
      return;
    }

    if (chainId !== 100) {
      alert('Please switch to Gnosis Chain to mint');
      return;
    }

    sendTransaction({
      to: MOCK_NFT_ADDRESS,
      value: MINT_PRICE,
    });
  };

  return (
    <section className="flex flex-col items-center justify-center max-w-lg pt-2 sm:pt-4 w-full mx-auto">
      <div className="flex w-full flex-col gap-4 items-center">
        <h2 className="text-3xl font-bold text-center mb-1">NFT Minting</h2>

        <div className="flex flex-col gap-4 w-full max-w-xs">
          <Button color="primary" onClick={handleChainSwitch} className="w-full" disabled={isPending}>
            {chainId === 100 ? 'Switch to Sepolia' : 'Switch to Gnosis'}
          </Button>

          <Button color="secondary" onClick={handleMint} isLoading={isPending} className="w-full">
            Mint NFT (0.01 xDAI)
          </Button>

          <div className="text-center text-small">Current Chain: {chainId || 'Not Connected'}</div>
          {isConfirming && <div>Waiting for confirmation...</div>}
          {isConfirmed && <div>Transaction confirmed.</div>}
          {error && <div>Error: {(error as BaseError).shortMessage || error.message}</div>}
        </div>
      </div>
    </section>
  );
};

export default NFTPage;
