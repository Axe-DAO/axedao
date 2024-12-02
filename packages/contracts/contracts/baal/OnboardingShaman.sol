// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IBaal } from "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import { IMembershipToken } from "../interfaces/IMembershipToken.sol";

contract OnboardingShaman {
  IMembershipToken public immutable membershipToken;

  constructor(address _membershipToken) {
    membershipToken = IMembershipToken(_membershipToken);
  }
}
