import { Address } from 'viem';

type ConfigType = {
  walletConnectProjectId: string;
  sepoliaProviderUrl: string;
  gnosisProviderUrl: string;
  optimismProviderUrl: string;
  axeTokenAddress: Address;
  axeDaoAddress: Address;
  axeTreasuryAddress: Address;
  axeDaoTreasuryAddress: Address;
  axeDaoSharesAddress: Address;
  axeDaoLootAddress: Address;
  axeSwapTokenAddress: Address;
  axeMembershipAddress: Address;
  axeMembershipCouncilAddress: Address;
  uniswapV2PairAddress: Address;
  uniswapV2RouterAddress: Address;
  pinataGatewayUrl: string;
  pinataJwt: string;
  pinataFileGroupId: string;
  databaseUrl: string;
  nextAuthSecret: string;
  axeDaoSiteUrl: string;
  axeDaoEmail: string;
  axeDaoDiscord: string;
};

const envMode = process.env.NEXT_PUBLIC_APP_ENV?.toLowerCase();

const isServer = typeof window === 'undefined';

const ENV: ConfigType = {
  walletConnectProjectId: required(
    process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID,
    'NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID',
  ),
  sepoliaProviderUrl:
    envMode === 'test'
      ? required(process.env.NEXT_PUBLIC_SEPOLIA_PROVIDER, 'NEXT_PUBLIC_SEPOLIA_PROVIDER')
      : process.env.NEXT_PUBLIC_SEPOLIA_PROVIDER || '',
  gnosisProviderUrl:
    envMode === 'prod'
      ? required(process.env.NEXT_PUBLIC_GNOSIS_PROVIDER, 'NEXT_PUBLIC_GNOSIS_PROVIDER')
      : process.env.NEXT_PUBLIC_GNOSIS_PROVIDER || '',
  optimismProviderUrl:
    envMode === 'prod'
      ? required(process.env.NEXT_PUBLIC_OP_PROVIDER, 'NEXT_PUBLIC_OP_PROVIDER')
      : process.env.NEXT_PUBLIC_OP_PROVIDER || '',
  axeTokenAddress: required(process.env.NEXT_PUBLIC_AXE_TOKEN_ADDRESS, 'NEXT_PUBLIC_AXE_TOKEN_ADDRESS') as Address,
  axeDaoAddress: required(process.env.NEXT_PUBLIC_AXE_DAO_ADDRESS, 'NEXT_PUBLIC_AXE_DAO_ADDRESS') as Address,
  axeTreasuryAddress: required(
    process.env.NEXT_PUBLIC_AXE_TREASURY_ADDRESS,
    'NEXT_PUBLIC_AXE_TREASURY_ADDRESS',
  ) as Address,
  axeDaoTreasuryAddress: required(
    process.env.NEXT_PUBLIC_AXE_DAO_TREASURY_ADDRESS,
    'NEXT_PUBLIC_AXE_DAO_TREASURY_ADDRESS',
  ) as Address,
  axeDaoSharesAddress: required(
    process.env.NEXT_PUBLIC_AXE_DAO_SHARES_ADDRESS,
    'NEXT_PUBLIC_AXE_DAO_SHARES_ADDRESS',
  ) as Address,
  axeDaoLootAddress: required(
    process.env.NEXT_PUBLIC_AXE_DAO_LOOT_ADDRESS,
    'NEXT_PUBLIC_AXE_DAO_LOOT_ADDRESS',
  ) as Address,
  axeSwapTokenAddress: required(
    process.env.NEXT_PUBLIC_AXE_SWAP_TOKEN_ADDRESS,
    'NEXT_PUBLIC_AXE_SWAP_TOKEN_ADDRESS',
  ) as Address,
  axeMembershipAddress: required(
    process.env.NEXT_PUBLIC_AXE_MEMBERSHIP_ADDRESS,
    'NEXT_PUBLIC_AXE_MEMBERSHIP_ADDRESS',
  ) as Address,
  axeMembershipCouncilAddress: required(
    process.env.NEXT_PUBLIC_COUNCIL_SHAMAN_ADDRESS,
    'NEXT_PUBLIC_COUNCIL_SHAMAN_ADDRESS',
  ) as Address,
  uniswapV2PairAddress: required(
    process.env.NEXT_PUBLIC_UNISWAPV2PAIR_ADDRESS,
    'NEXT_PUBLIC_UNISWAPV2PAIR_ADDRESS',
  ) as Address,
  uniswapV2RouterAddress: required(
    process.env.NEXT_PUBLIC_UNISWAPV2ROUTER_ADDRESS,
    'NEXT_PUBLIC_UNISWAPV2ROUTER_ADDRESS',
  ) as Address,
  pinataGatewayUrl: required(process.env.NEXT_PUBLIC_PINATA_GATEWAY_URL, 'NEXT_PUBLIC_PINATA_GATEWAY_URL'),
  pinataJwt: isServer ? required(process.env.PINATA_JWT, 'PINATA_JWT') : '',
  pinataFileGroupId: required(process.env.NEXT_PUBLIC_PINATA_FILE_GROUP_ID, 'NEXT_PUBLIC_PINATA_FILE_GROUP_ID'),
  databaseUrl: isServer ? required(process.env.DATABASE_URL, 'DATABASE_URL') : '',
  nextAuthSecret: isServer ? required(process.env.NEXTAUTH_SECRET, 'NEXTAUTH_SECRET') : '',
  axeDaoSiteUrl: required(process.env.NEXT_PUBLIC_AXE_DAO_SITE_URL, 'NEXT_PUBLIC_AXE_DAO_SITE_URL'),
  axeDaoEmail: required(process.env.NEXT_PUBLIC_AXE_DAO_EMAIL, 'NEXT_PUBLIC_AXE_DAO_EMAIL'),
  axeDaoDiscord: required(process.env.NEXT_PUBLIC_AXE_DAO_DISCORD, 'NEXT_PUBLIC_AXE_DAO_DISCORD'),
};

function required(value: string | undefined, name: string): string {
  if (!value) {
    throw new Error(`Missing required environment variable ${name}`);
  }
  return value;
}

export default ENV;
