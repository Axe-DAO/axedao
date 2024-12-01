import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-ethers';
import '@typechain/hardhat';

import * as dotenv from 'dotenv';
dotenv.config({ path: ['.env.local', '.env'] });

const config: HardhatUserConfig = {
  solidity: '0.8.24',
  typechain: {
    outDir: 'typechain-types',
    target: 'ethers-v6',
  },
  networks: {
    hardhat: {
      chainId: 1337,
      forking:
        process.env.FORK?.toLowerCase() === 'true'
          ? {
              url: `${process.env.HTTPS_PROVIDER_URL_SEPOLIA}`,
              blockNumber: 5355418,
            }
          : undefined,
    },
    sepolia: {
      url: `${process.env.HTTPS_PROVIDER_URL_SEPOLIA}`,
    },
  },
};

export default config;
