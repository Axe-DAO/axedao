'use client';

import { useInitializeCouncilState } from '@/hooks/state/dao';
import Candidates from './Candidates';
import Council from './Council';
import CouncilMembership from './CouncilMembership';

const CouncilPanel: React.FC = () => {
  useInitializeCouncilState();

  return (
    <div className="flex w-full flex-col gap-2 sm:gap-4 items-center">
      <h2 className="text-3xl font-bold text-center mb-1">Council</h2>
      <p className="text-center">The Council is the decision-making body of the Axé DAO.</p>
      <CouncilMembership />
      <div className="w-full mt-4">
        <h3 className="text-xl font-semibold mb-2">Current Council</h3>
        <Council />
        <Candidates />
      </div>
    </div>
  );
};

export default CouncilPanel;
