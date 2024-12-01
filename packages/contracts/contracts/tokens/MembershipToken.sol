// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IMembershipToken } from "../interfaces/IMembershipToken.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MembershipToken is IMembershipToken, ERC721, Ownable {
  address internal donationReceiver;
  address internal donationToken;
  uint256 internal donationAmount;
  uint256 internal nativeDonationAmount;
  uint256 internal memberCount = 0;
  mapping(address => uint256) public members;
  string private baseTokenURI;

  modifier registerNewMember() {
    if (isMember(msg.sender)) revert AlreadyMemberError(msg.sender);
    members[msg.sender] = ++memberCount;
    _;
  }

  constructor(
    address _owner,
    address _donationReceiver,
    address _donationToken,
    uint256 _donationAmount,
    uint256 _nativeDonationAmount,
    string memory _baseTokenURI
  ) ERC721(unicode"Axé DAO Membership", "AXDM") Ownable(_owner) {
    donationReceiver = _donationReceiver;
    donationToken = _donationToken;
    donationAmount = _donationAmount;
    nativeDonationAmount = _nativeDonationAmount;
    baseTokenURI = _baseTokenURI;
  }

  function donate() external override registerNewMember {
    require(
      IERC20(donationToken).transferFrom(msg.sender, donationReceiver, donationAmount),
      "Failed to transfer donation"
    );
    _mint(msg.sender, memberCount);
  }

  function isMember(address _user) public view override returns (bool) {
    return members[_user] != 0;
  }

  receive() external payable registerNewMember {
    _handleNativeDonation();
    _mint(msg.sender, memberCount);
  }

  function _handleNativeDonation() internal {
    if (msg.value < nativeDonationAmount) {
      revert InsufficientDonationError(msg.value, nativeDonationAmount);
    }
    uint256 refundAmount = msg.value - nativeDonationAmount;
    (bool success, ) = donationReceiver.call{ value: nativeDonationAmount }("");
    require(success, "Failed to forward donation");
    if (refundAmount > 0) {
      (bool refundSuccess, ) = msg.sender.call{ value: refundAmount }("");
      require(refundSuccess, "Failed to refund excess amount");
    }
  }

  function _baseURI() internal view override returns (string memory) {
    return baseTokenURI;
  }

  function getMemberCount() external view override returns (uint256) {
    return memberCount;
  }

  function getMemberId(address _user) external view returns (uint256) {
    return members[_user];
  }

  function setTokenDonationAmount(uint256 _donationAmount) external onlyOwner {
    donationAmount = _donationAmount;
  }

  function setNativeDonationAmount(uint256 _nativeDonationAmount) external onlyOwner {
    nativeDonationAmount = _nativeDonationAmount;
  }

  function setDonationReceiver(address _donationReceiver) external onlyOwner {
    donationReceiver = _donationReceiver;
  }

  function setDonationToken(address _donationToken) external onlyOwner {
    donationToken = _donationToken;
  }
}
