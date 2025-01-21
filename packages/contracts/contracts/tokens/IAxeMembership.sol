// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title IAxeMembership
 * @notice IAxeMembership is the interface for the Axe Membership token.
 */
interface IAxeMembership is IERC721 {
  struct Candidate {
    uint256 index;
    // 31 bytes are enough for max delegation count to a single candidate
    // and it allows packing the bool into the same storage slot
    uint248 delegationCount;
    bool available;
  }

  error NotAMemberError();
  error AlreadyMemberError(address member);
  error InsufficientDonationError(uint256 amount, uint256 requiredAmount);
  error DonationOptionNotAvailable();

  event ERC20DonationReceived(address indexed from, uint256 amount);
  event NativeDonationReceived(address indexed from, uint256 amount);
  event ObrigadoMuitoAxe(address indexed member, uint256 memberId);
  event CandidateEnlisted(address indexed candidate);
  event CandidateResigned(address indexed candidate);
  event VoteDelegated(address indexed delegator, address indexed candidate);
  event VoteUndelegated(address indexed delegator, address indexed candidate);

  function donate() external;

  function isMember(address user) external view returns (bool);

  function getMemberCount() external view returns (uint256);

  function getMemberId(address user) external view returns (uint256);

  function enlistAsCandidate() external;

  function resignAsCandidate() external;

  function delegate(address candidate) external;

  function undelegate() external;

  function getCandidate(address candidate) external view returns (Candidate memory);

  function getTopCandidates(uint256 limit) external view returns (address[] memory);

  function getNumberOfRankedGroups() external view returns (uint256);

  function getRankedGroupAtIndex(uint256 index) external view returns (address[] memory);

  function getDelegationCountForGroupAtIndex(uint256 index) external view returns (uint256);

  function getNativeDonationAmount() external view returns (uint256);

  function setNativeDonationAmount(uint256 amount) external;

  function getTokenDonationAmount() external view returns (uint256);

  function setTokenDonationAmount(uint256 amount) external;

  function setDonationToken(address token) external;

  function setDonationReceiver(address receiver) external;
}
