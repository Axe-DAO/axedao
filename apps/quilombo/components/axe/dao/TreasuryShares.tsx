'use client';

import { Address } from 'viem';
import { useAccount } from 'wagmi';

import ENV from '@/config/environment';
import { useReadErc20BalanceOf, useReadErc20TotalSupply } from '@/generated';
import { add, divide, format, from, greaterThan, multiply } from 'dnum';
import { Suspense } from 'react';
import { CouncilBadge, MemberBadge } from './Badges';

const TreasuryShares: React.FC = () => {
  const account = useAccount();
  // SHARES
  const { data: userDaoShares } = useReadErc20BalanceOf({
    address: ENV.axeDaoSharesAddress,
    args: [account.address as Address],
  });
  const { data: totalShares } = useReadErc20TotalSupply({
    address: ENV.axeDaoSharesAddress,
  });
  // LOOT
  const { data: userDaoLoot } = useReadErc20BalanceOf({
    address: ENV.axeDaoLootAddress,
    args: [account.address as Address],
  });
  const { data: totalLoot } = useReadErc20TotalSupply({
    address: ENV.axeDaoLootAddress,
  });
  const { data: usdDao } = useReadErc20BalanceOf({
    address: ENV.axeSwapTokenAddress,
    args: [ENV.axeDaoTreasuryAddress],
  });

  const isMember = !!userDaoLoot && userDaoLoot > 0;
  const isCouncil = !!userDaoShares && userDaoShares > 0;
  const totalRageQuitShares = add([userDaoShares || BigInt(0), 18], [userDaoLoot || BigInt(0), 18]);
  const sumOfAllShares = add([totalShares || BigInt(0), 18], [totalLoot || BigInt(0), 18]);
  const userTreasuryPercent = greaterThan(sumOfAllShares, 0)
    ? multiply(divide(totalRageQuitShares, sumOfAllShares), 100)
    : from(0);
  const userTreasuryUsdTotal = multiply(divide([usdDao || BigInt(0), 18], from(100)), userTreasuryPercent);

  return (
    <div className="flex flex-col w-full items-center">
      <div className="text-2xl mb-1 sm:mb-2">Membership</div>
      <div className="flex flex-col gap-2 w-full px-2">
        <div className="flex gap-2 sm:gap-4">
          <MemberBadge isMember={isMember} />
          {isMember ? (
            `You own ${format(totalRageQuitShares)} shares of the community treasury equivalent to ${format(userTreasuryPercent, 2)}% (or $ ${format(userTreasuryUsdTotal, 2)})`
          ) : (
            <span>You&apos;re not a member.</span>
          )}
        </div>
        <div className="flex gap-2 sm:gap-4">
          <CouncilBadge isCouncil={isCouncil} />
          {isCouncil ? `You own ${format([userDaoShares, 18])} voting shares` : 'Not a council member'}
        </div>
      </div>
    </div>
  );
};

export default function DaoMembership() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <TreasuryShares />
    </Suspense>
  );
}
