// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../contracts/test/MockERC20.sol";
import "../contracts/tokens/MembershipToken.sol";

contract MembershipDelegationTest is Test {
  MockERC20 paymentToken;
  MembershipToken membershipToken;
  uint256 constant NUM_TEST_USERS = 100;
  address[] testUsers = new address[](NUM_TEST_USERS);
  uint256 tokenDonationAmount;

  function setUp() public {
    // Deploy the MockERC20 token
    paymentToken = new MockERC20("Payment Token", "PTK");
    tokenDonationAmount = 10 ** 10 * IERC20Metadata(paymentToken).decimals();

    // Deploy the MembershipToken NFT
    membershipToken = new MembershipToken(
      address(this),
      address(this),
      address(paymentToken),
      tokenDonationAmount,
      0.00001 ether,
      "ipfs://Qmb6cxks2ZMfWTXravK5RHf7LYLRYrtgxL14Zg47hFNxjU/quilombo-early-design.json"
    );

    // Set up test users
    for (uint256 i = 0; i < NUM_TEST_USERS; i++) {
      address user = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
      testUsers[i] = user;
      vm.deal(user, 1 ether); // Give each user some ether
      paymentToken.mint(user, 1000 ** 10 * 18); // Mint payment tokens to each user
      vm.startPrank(user);
      paymentToken.approve(address(membershipToken), tokenDonationAmount);
      membershipToken.donate();
      vm.stopPrank();
    }
  }

  function testEnlistment() public {
    address candidate = testUsers[0];
    vm.startPrank(candidate);
    membershipToken.enlistAsCandidate();
    vm.stopPrank();

    // Assert the candidate is enlisted
    MembershipToken.Candidate memory structCandidate = membershipToken.getCandidate(candidate);
    assertTrue(structCandidate.available);
    assertEq(structCandidate.index, 0);
    assertEq(structCandidate.delegationCount, 1);
  }

  function testResignation() public {
    address candidate = testUsers[0];
    vm.startPrank(candidate);
    membershipToken.enlistAsCandidate();
    membershipToken.resignAsCandidate();
    vm.stopPrank();

    // Assert the candidate is no longer enlisted
    MembershipToken.Candidate memory structCandidate = membershipToken.getCandidate(candidate);
    assertFalse(structCandidate.available);
  }

  function testDelegation() public {
    address delegator = testUsers[0];
    address delegatee = testUsers[1];
    vm.prank(delegatee);
    membershipToken.enlistAsCandidate();

    vm.startPrank(delegator);
    membershipToken.delegate(delegatee);
    vm.stopPrank();

    // Assert the delegation is successful
    assertEq(membershipToken.delegations(delegator), delegatee);
  }

  function testUndelegation() public {
    address delegator = testUsers[0];
    address delegatee = testUsers[1];
    vm.prank(delegatee);
    membershipToken.enlistAsCandidate();

    vm.startPrank(delegator);
    membershipToken.delegate(delegatee);
    membershipToken.undelegate();
    vm.stopPrank();

    // Assert the undelegation is successful
    assertEq(membershipToken.delegations(delegator), address(0));
  }

  // Additional tests for large number of users can be added similarly
}
