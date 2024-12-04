// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../contracts/test/MockERC20.sol";
import { MembershipCouncil } from "../contracts/tokens/MembershipCouncil.sol";

contract MembershipDelegationTest is Test {
  MockERC20 paymentToken;
  MembershipCouncil membershipCouncil;
  uint256 constant NUM_TEST_USERS = 100;
  address[] testUsers = new address[](NUM_TEST_USERS);
  uint256 tokenDonationAmount;

  function setUp() public {
    // Deploy the MockERC20 token
    paymentToken = new MockERC20("Payment Token", "PTK");
    tokenDonationAmount = 10 ** 10 * IERC20Metadata(paymentToken).decimals();

    // Deploy the MembershipToken NFT
    membershipCouncil = new MembershipCouncil(
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
      paymentToken.approve(address(membershipCouncil), tokenDonationAmount);
      membershipCouncil.donate();
      vm.stopPrank();
    }
  }

  function setUpCandidates() public {
    for (uint256 i = 0; i < 10; i++) {
      address user = testUsers[i];
      vm.startPrank(user);
      membershipCouncil.enlistAsCandidate();
      vm.stopPrank();
    }
  }

  function testEnlistAndResign() public {
    address candidate = testUsers[0];
    vm.prank(candidate);
    membershipCouncil.enlistAsCandidate();

    // Assert the candidate is enlisted
    MembershipCouncil.Candidate memory structCandidate = membershipCouncil.getCandidate(candidate);
    assertTrue(structCandidate.available, "Candidate should be enlisted");
    assertEq(structCandidate.index, 0, "Candidate should be at index 0");
    assertEq(structCandidate.delegationCount, 1, "Candidate should have 1 delegation");

    assertEq(
      membershipCouncil.getNumberOfDelegationGroups(),
      1,
      "There should be 1 delegation group. Candidate auto self-delegated on enlistment."
    );

    vm.prank(testUsers[1]);
    membershipCouncil.delegate(candidate);

    assertEq(
      membershipCouncil.getNumberOfDelegationGroups(),
      1,
      "There should still be 1 delegation group after other user delegates to single candidate."
    );

    vm.prank(testUsers[2]);
    membershipCouncil.enlistAsCandidate();

    assertEq(
      membershipCouncil.getNumberOfDelegationGroups(),
      2,
      "There should be 2 delegation groups after second candidate enlisted."
    );

    vm.prank(candidate);
    membershipCouncil.resignAsCandidate();
    structCandidate = membershipCouncil.getCandidate(candidate);
    assertFalse(structCandidate.available);

    assertEq(
      membershipCouncil.getNumberOfDelegationGroups(),
      1,
      "There should be 1 delegation group. One of the candidates resigned."
    );
  }

  function testDelegateUndelegate() public {
    address delegator = testUsers[0];
    address delegatee = testUsers[1];
    vm.prank(delegatee);
    membershipCouncil.enlistAsCandidate();

    vm.startPrank(delegator);
    membershipCouncil.delegate(delegatee);
    assertEq(membershipCouncil.delegations(delegator), delegatee);

    membershipCouncil.undelegate();
    assertEq(membershipCouncil.delegations(delegator), address(0));
  }

  function testSortedDelegations() public {
    address delegator = testUsers[0];
    address delegatee = testUsers[1];
  }
}
