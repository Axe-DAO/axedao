'use client';

import { Tab, Tabs } from '@nextui-org/tabs';
import { useQueryState } from 'nuqs';

import { CouncilPanel, DaoMembership, Proposals, Treasury, TreasuryShares } from '@/components/axe/dao';

const DaoPage = () => {
  const [tab, setTab] = useQueryState('tab', {
    defaultValue: 'dao',
    parse: (value) => value || 'dao',
  });

  return (
    <section className="flex flex-col items-center justify-center max-w-lg pt-2 sm:pt-4 w-full mx-auto">
      <Tabs
        aria-label="Axé DAO Membership and Council"
        color="primary"
        size="lg"
        fullWidth
        selectedKey={tab}
        onSelectionChange={(key) => setTab(key.toString())}
      >
        <Tab key="dao" title="Axé DAO" className="w-full">
          <div className="flex w-full flex-col gap-2 sm:gap-4 items-center">
            <h2 className="text-3xl font-bold text-center mb-1">Axé DAO</h2>
            <p className="text-center">The Axé DAO governs the community treasury and the Axé Safe.</p>
            <DaoMembership />
          </div>
        </Tab>
        <Tab key="council" title="Council" className="w-full">
          <CouncilPanel />
        </Tab>
        <Tab key="proposals" title="Proposals" className="w-full">
          <div className="flex w-full flex-col gap-2 sm:gap-4 items-center">
            <h2 className="text-3xl font-bold text-center mb-1">Proposals</h2>
            <p className="text-center">The following proposals are currently active.</p>
            <Proposals />
          </div>
        </Tab>
        <Tab key="assets" title="Assets" className="w-full">
          <div className="flex w-full flex-col gap-2 sm:gap-4 items-center">
            <h2 className="text-3xl font-bold text-center mb-1">Assets</h2>
            <p className="text-center">The Axé DAO controls multiple treasuries.</p>
            <Treasury />
            <TreasuryShares />
          </div>
        </Tab>
      </Tabs>
    </section>
  );
};

export default DaoPage;
