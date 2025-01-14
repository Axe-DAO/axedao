import { defineConfig } from '@wagmi/cli';
import { etherscan, foundry, react } from '@wagmi/cli/plugins';
import { Address } from 'viem';
import { sepolia } from 'viem/chains';

const etherscanApiKey = process.env.NEXT_PUBLIC_ETHERSCAN_API_KEY;
const axeDaoAddress = process.env.NEXT_PUBLIC_DAO_ADDRESS;

if (!etherscanApiKey || !axeDaoAddress) {
  throw new Error('NEXT_PUBLIC_ETHERSCAN_API_KEY and NEXT_PUBLIC_DAO_ADDRESS must be set');
}

export default defineConfig({
  out: 'generated/index.ts',
  plugins: [
    foundry({
      project: '../../packages/contracts',
    }),
    etherscan({
      apiKey: etherscanApiKey,
      chainId: sepolia.id,
      contracts: [
        {
          name: 'Baal',
          address: {
            [sepolia.id]: axeDaoAddress as Address,
          },
        },
      ],
    }),
    react(),
  ],
});
