// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IMembershipCouncil is IERC721 {
  struct Candidate {
    bool available;
    uint256 index;
    uint256 delegationCount;
  }

  error NotAMemberError();
  error AlreadyMemberError(address _member);
  error InsufficientDonationError(uint256 _amount, uint256 _requiredAmount);

  event ERC20DonationReceived(address indexed _donator, uint256 _amount);
  event NativeDonationReceived(address indexed _donator, uint256 _amount);
  event CandidateEnlisted(address indexed _candidate);
  event CandidateResigned(address indexed _candidate);
  event VoteDelegated(address indexed _delegator, address indexed _candidate);
  event VoteUndelegated(address indexed _delegator);

  function donate() external;

  function isMember(address _user) external view returns (bool);

  function getMemberCount() external view returns (uint256);

  function getMemberId(address _user) external view returns (uint256);

  function enlistAsCandidate() external;

  function resignAsCandidate() external;

  function delegate(address _candidate) external;

  function undelegate() external;

  function getCandidate(address _candidate) external view returns (Candidate memory);

  function getNumberOfSortedGroups() external view returns (uint256);

  function getSortedGroupAtIndex(uint256 _sortedIndex) external view returns (address[] memory);

  function getSortedGroupDelegationCount(uint256 _sortedIndex) external view returns (uint256);
}
