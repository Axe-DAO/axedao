// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IAxeMembershipCouncil
 * @notice Interface for the Axe Membership Council
 */
interface IAxeMembershipCouncil {
  struct CouncilMember {
    uint256 index;
    bool active;
  }

  error InvalidCouncilLimit(uint256 minSize, uint256 requestedSize);
  error UpdateCooldownInEffect();
  error InvalidSeatReplacement(address candidate, address existingSeat);
  error InvalidSeatClaim(address candidate);
  error OnlyReplacementAllowed(address candidate);
  error InsufficientLoot(address candidate);
  error InsufficientShares(address member);

  event CouncilUpdateRequested(uint256 currentSize, uint256 numJoining, uint256 numLeaving);
  event CouncilLimitIncreased(uint256 newLimit);
  event SeatClaimed(address indexed candidate, address indexed replaced);

  function claimSeat(address existingSeat) external;

  function requestCouncilUpdate() external;

  function getCurrentCouncilSize() external view returns (uint256);

  function getCouncilMemberAtIndex(uint256 index) external view returns (address);

  function getCurrentMembers() external view returns (address[] memory);

  function getJoiningMembers() external view returns (address[] memory);

  function getLeavingMembers() external view returns (address[] memory);

  function canRequestCouncilUpdate() external view returns (bool);

  function increaseCouncilLimit(uint256 newLimit) external;
}
