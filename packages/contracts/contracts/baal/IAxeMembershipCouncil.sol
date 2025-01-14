// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IAxeMembershipCouncil {
  struct CouncilMember {
    uint256 index;
    bool active;
  }

  error InvalidCouncilSize(uint256 _minSize, uint256 _requestedSize);
  error FormationCooldownError();
  error InvalidSeatReplacement(address _candidate, address _existingSeat);
  error InvalidSeatClaim(address _candidate);
  error InsufficientLoot(address _candidate);
  error OnlyReplacementAllowed(address _candidate);

  event CouncilUpdateRequested(uint256 currentSize, uint256 numJoining, uint256 numLeaving);
  event SeatClaimed(address indexed candidate, address indexed replaced);

  function getCouncilSize() external view returns (uint256);

  function getCouncilMemberAtIndex(uint256 _index) external view returns (address);

  function getJoiningMembers() external view returns (address[] memory);

  function getLeavingMembers() external view returns (address[] memory);

  function requestCouncilUpdate() external;

  function claimSeat(address _existingSeat) external;
}
