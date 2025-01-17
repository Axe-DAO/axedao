// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IAXE } from "./IAXE.sol";

interface IAXESource is IAXE {
  /**
   * @notice Emits when Axé was issued and deposited to the treasury.
   * @param amount - the amount of new Axé minted
   */
  event AxeIssued(uint256 amount);

  /**
   * @dev Mints additional supply to the treasury.
   * @param amount - amount of AXE to mint
   */
  function issue(uint256 amount) external;
}
