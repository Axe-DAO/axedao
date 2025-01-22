import { Config, createConfig, http, webSocket } from 'wagmi';
import { Chain, gnosis, localhost, optimism, sepolia } from 'wagmi/chains';

import ENV, { getBaseUrl } from '@/config/environment';
import silk from '@/utils/silk.connector';
import { InitSilkOptions } from '@silk-wallet/silk-wallet-sdk/dist/lib/provider/types';

declare module 'wagmi' {
  interface Register {
    config: typeof wagmiConfig;
  }
}

console.info('Base URL: ', getBaseUrl());

export const silkInitOptions: InitSilkOptions = {
  config: { styles: { darkMode: false }, allowedSocials: ['Google'], authenticationMethods: ['email', 'social'] },
  project: {
    name: 'Quilombo',
    logo: `${getBaseUrl()}/quilombo-icon-512x512.png`,
    origin: getBaseUrl(),
    //    projectId:
    termsOfServiceUrl: `${getBaseUrl()}/terms-of-service`,
    privacyPolicyUrl: `${getBaseUrl()}/privacy-policy`,
  },
};

export const configureChains = (): [Chain, ...Chain[]] => {
  let chains: [Chain, ...Chain[]] = [gnosis, optimism];
  const appEnv = process.env.NEXT_PUBLIC_APP_ENV?.toLowerCase();
  if (appEnv === 'local') chains = [localhost];
  else if (appEnv === 'test') chains = [sepolia, gnosis];
  console.info(`Chains configured for '${appEnv}' mode.`);
  return chains;
};

export const getDefaultChain = (): Chain => {
  switch (process.env.NEXT_PUBLIC_APP_ENV?.toLowerCase()) {
    case 'local':
      return localhost;
    case 'test':
      return sepolia;
    default:
      return gnosis;
  }
};

export const getTransport = (chain: Chain | undefined) => {
  let url = '';
  switch (chain?.id) {
    case gnosis.id:
      url = ENV.gnosisProviderUrl;
      break;
    case optimism.id:
      url = ENV.optimismProviderUrl;
      break;
    case sepolia.id:
      url = ENV.sepoliaProviderUrl;
      break;
    case localhost.id:
      url = 'http://127.0.0.1:8545';
      break;
    case 31337:
      url = 'http://127.0.0.1:8545';
      break;
    default:
      url = '';
  }
  if (url.startsWith('wss')) return webSocket(url);
  return http(url);
};

/**
 * Default wagmi configuration
 */
const wagmiConfig: Config = createConfig({
  chains: configureChains(),
  connectors: [silk(silkInitOptions)],
  transports: {
    [optimism.id]: http(ENV.optimismProviderUrl),
    [gnosis.id]: http(ENV.gnosisProviderUrl),
    [sepolia.id]: http(ENV.sepoliaProviderUrl),
    [localhost.id]: http('http://127.0.0.1:8545'),
    [31337]: http('http://127.0.0.1:8545'), // hardhat
  },
  ssr: true,
});

export default wagmiConfig;
