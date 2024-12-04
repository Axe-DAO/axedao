// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test, console2 } from "forge-std/Test.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import { MembershipCouncil, IMembershipCouncil } from "../contracts/tokens/MembershipCouncil.sol";
import { MockERC20 } from "../contracts/test/MockERC20.sol";

contract MembershipDonationsTest is Test {
  IMembershipCouncil public token;

  address dao = 0x1c3ac998b698206CD2fb22bb422Bf14367470866;
  address donationReceiver = 0x114D5F3904dB2b4635528C08b1687ECB5468EE17;
  // anvil default accounts
  address private userA = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  address private userB = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
  address private userC = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

  MockERC20 swapToken = new MockERC20("Swap Token", "SWAP");
  uint256 tokenDonationAmount = 10 ** 10 * IERC20Metadata(swapToken).decimals();
  uint256 nativeDonationAmount = 0.00001 ether; // Works on Gnosis Chain (xDAI) since 'ether' is just a denomination unit

  function setUp() public {
    swapToken.mint(address(userA), 100 ** 10 * IERC20Metadata(address(swapToken)).decimals());
    swapToken.mint(address(userB), 100 ** 10 * IERC20Metadata(address(swapToken)).decimals());
    swapToken.mint(address(userC), 100 ** 10 * IERC20Metadata(address(swapToken)).decimals());
    // Give test users native tokens
    vm.deal(userA, 1 ether);
    vm.deal(userB, 1 ether);
    vm.deal(userC, 1 ether);
    token = new MembershipCouncil(
      dao,
      donationReceiver,
      address(swapToken),
      tokenDonationAmount,
      nativeDonationAmount,
      "ipfs://Qmb6cxks2ZMfWTXravK5RHf7LYLRYrtgxL14Zg47hFNxjU/quilombo-early-design.json"
    );
  }

  function test_ERC20Donation() public {
    uint256 oldMemberCount = token.getMemberCount();
    uint256 oldSwapTokenBalance = swapToken.balanceOf(donationReceiver);
    uint256 donationAmount = 10 ** 10 * IERC20Metadata(swapToken).decimals();
    vm.startPrank(userA);
    vm.expectRevert(); // Insufficient allowance
    token.donate();
    IERC20(swapToken).approve(address(token), donationAmount);
    token.donate();
    assertTrue(token.isMember(userA), "User A should be a member");
    assertEq(token.getMemberCount(), oldMemberCount + 1, "Member count should increase by 1");
    assertTrue(
      token.ownerOf(token.getMemberCount()) == userA,
      "User A should be the owner of the new membership token"
    );
    assertEq(
      swapToken.balanceOf(address(donationReceiver)),
      oldSwapTokenBalance + donationAmount,
      "Receiver should have received the donation amount"
    );
    // Testing the newMemberOnlymodifier here
    vm.expectRevert(abi.encodeWithSelector(IMembershipCouncil.AlreadyMemberError.selector, userA));
    token.donate();
    vm.stopPrank();
  }

  function test_NativeDonation() public {
    uint256 oldMemberCount = token.getMemberCount();
    uint256 oldBalance = donationReceiver.balance;

    vm.startPrank(userB);
    (bool success, ) = address(token).call{ value: nativeDonationAmount }("");
    require(success, "Failed to send native tokens from user B");
    assertTrue(token.isMember(userB), "User B should be a member");
    assertEq(token.getMemberCount(), oldMemberCount + 1, "Member count should increase by 1");
    assertTrue(
      token.ownerOf(token.getMemberCount()) == userB,
      "User B should be the owner of the new membership token"
    );
    assertEq(
      donationReceiver.balance,
      oldBalance + nativeDonationAmount,
      "Receiver should have received the donation amount from User B"
    );
    vm.stopPrank();

    oldBalance = donationReceiver.balance;
    uint256 oldUserCBalance = userC.balance;

    vm.startPrank(userC);
    vm.expectRevert(
      abi.encodeWithSelector(
        IMembershipCouncil.InsufficientDonationError.selector,
        nativeDonationAmount - 0.000005 ether,
        nativeDonationAmount
      )
    );
    (success, ) = address(token).call{ value: nativeDonationAmount - 0.000005 ether }("");
    (success, ) = address(token).call{ value: 3 * nativeDonationAmount }("");
    require(success, "Failed to send native tokens from user C");
    assertTrue(token.isMember(userC), "User C should be a member");
    assertEq(
      token.getMemberCount(),
      oldMemberCount + 2,
      "Original member count should have increased by 2"
    );
    assertTrue(
      token.ownerOf(token.getMemberCount()) == userC,
      "User C should be the owner of the new membership token"
    );
    assertEq(
      donationReceiver.balance,
      oldBalance + nativeDonationAmount,
      "Receiver should have received the donation amount from User C"
    );
    assertEq(
      userC.balance,
      oldUserCBalance - nativeDonationAmount,
      "User C should have spent the donation amount"
    );
    vm.stopPrank();
  }
}
