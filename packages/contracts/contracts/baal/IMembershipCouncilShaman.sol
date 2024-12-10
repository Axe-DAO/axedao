// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IMembershipCouncilShaman {
  function getCurrentCouncil() external view returns (address[] memory);

  /**
   * @return remainingMembers - the members that are already in the council
   * @return newMembers - the members that are not in the council
   */
  function determineCouncilChanges() external view returns (address[] memory, address[] memory);

  function formCouncil() external returns (address[] memory);
}
