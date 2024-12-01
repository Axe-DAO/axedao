// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IMembershipToken is IERC721 {
  error AlreadyMemberError(address _member);
  error InsufficientDonationError(uint256 _amount, uint256 _requiredAmount);

  function donate() external;

  function isMember(address _user) external view returns (bool);

  function getMemberCount() external view returns (uint256);

  function getMemberId(address _user) external view returns (uint256);
}
