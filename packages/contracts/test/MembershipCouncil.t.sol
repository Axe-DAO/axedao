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
      membershipCouncil.getNumberOfSortedGroups(),
      1,
      "There should be 1 delegation group. Candidate auto self-delegated on enlistment."
    );

    vm.prank(testUsers[1]);
    membershipCouncil.delegate(candidate);

    assertEq(
      membershipCouncil.getNumberOfSortedGroups(),
      1,
      "There should still be 1 delegation group after other user delegates to single candidate."
    );

    vm.prank(testUsers[2]);
    membershipCouncil.enlistAsCandidate();

    assertEq(
      membershipCouncil.getNumberOfSortedGroups(),
      2,
      "There should be 2 sorted groups after second candidate enlisted."
    );

    vm.prank(candidate);
    membershipCouncil.resignAsCandidate();
    structCandidate = membershipCouncil.getCandidate(candidate);
    assertFalse(structCandidate.available);

    assertEq(
      membershipCouncil.getNumberOfSortedGroups(),
      1,
      "There should be 1 sorted group. One of the candidates resigned."
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

  /**
   * @notice Test a complex delegation scenario with multiple candidates and delegations
   * @dev This test covers a variety of delegation patterns, including:
   * - Multiple candidates enlisting and delegating
   * - Delegations to multiple candidates
   * - Undelegations and their effects on sorting
   * - Group merging and sorting integrity
   */
  function testComplexDelegationScenario() public {
    // Set up initial candidates (first 5 users become candidates)
    _setUpCandidates(5);
    // Verify initial state
    assertEq(membershipCouncil.getNumberOfSortedGroups(), 1, "Should have 5 initial candidates in 1 group");
    assertEq(membershipCouncil.getSortedGroupAtIndex(0).length, 5, "Group 0 should have 5 candidates");

    // First wave of delegations: 10 members delegate to candidate 0
    _delegateUsers(testUsers[0], 10, 20);

    // Verify candidate 0 is now the top candidate
    address[] memory topGroup = membershipCouncil.getSortedGroupAtIndex(0);
    assertEq(topGroup.length, 1, "1W: Top group should have 1 candidate");
    assertEq(topGroup[0], testUsers[0], "1W: Candidate 0 should be top candidate");
    assertEq(
      membershipCouncil.getCandidate(testUsers[0]).delegationCount,
      11, // 10 delegators + self
      "Candidate 0 should have 11 delegations"
    );
    assertEq(membershipCouncil.getNumberOfSortedGroups(), 2, "1W: There should be 2 sorted groups");
    assertEq(membershipCouncil.getSortedGroupDelegationCount(0), 11, "1W: Top group should be 11 delegations");
    assertEq(membershipCouncil.getSortedGroupDelegationCount(1), 1, "1W: Second group should be 1 delegations");

    // Second wave: 5 members delegate to candidate 1 and 7 delegate to candidate 2
    _delegateUsers(testUsers[1], 20, 25);
    _delegateUsers(testUsers[2], 25, 32);

    assertEq(membershipCouncil.getNumberOfSortedGroups(), 4, "W2: There should be 4 sorted groups");
    // Verify sorting remains correct
    topGroup = membershipCouncil.getSortedGroupAtIndex(0);
    address[] memory secondGroup = membershipCouncil.getSortedGroupAtIndex(1);
    address[] memory thirdGroup = membershipCouncil.getSortedGroupAtIndex(2);
    address[] memory fourthGroup = membershipCouncil.getSortedGroupAtIndex(3);
    assertEq(topGroup[0], testUsers[0], "W2: Candidate 0 should still be top");
    assertEq(secondGroup[0], testUsers[2], "W2: Candidate 2 should be second");
    assertEq(thirdGroup[0], testUsers[1], "W2: Candidate 1 should be third");
    assertEq(fourthGroup.length, 2, "W2: There should be 2 candidates left in the fourth position");
    assertTrue(
      fourthGroup[0] == testUsers[3] || fourthGroup[0] == testUsers[4],
      "W2: Candidate 3 or 4 should be fourth"
    );
    assertEq(membershipCouncil.getSortedGroupDelegationCount(1), 8, "W2: Second group should be 8 delegations");
    assertEq(membershipCouncil.getSortedGroupDelegationCount(2), 6, "W2: Third group should be 6 delegations");
    assertEq(membershipCouncil.getSortedGroupDelegationCount(3), 1, "W2: Fourth group should be 1 delegations");

    // Candidate 2 resigns
    vm.prank(testUsers[2]);
    membershipCouncil.resignAsCandidate();

    assertEq(
      membershipCouncil.getNumberOfSortedGroups(),
      3,
      "R1: Should have 3 groups after resignation of candidate 2"
    );

    // New candidate enlists (user 5) and gets more delegations than current top
    vm.prank(testUsers[5]);
    membershipCouncil.enlistAsCandidate();

    _delegateUsers(testUsers[5], 32, 50); // 18 delegations

    // Verify new candidate is now top
    assertEq(membershipCouncil.getNumberOfSortedGroups(), 4, "W3: There should be 4 sorted groups");
    topGroup = membershipCouncil.getSortedGroupAtIndex(0);
    assertEq(topGroup[0], testUsers[5], "E1:Newly enlisted candidate should be top");
    assertEq(
      membershipCouncil.getCandidate(testUsers[5]).delegationCount,
      19, // 18 delegators + self
      "W3:New top candidate should have 19 delegations"
    );
    assertEq(membershipCouncil.getSortedGroupDelegationCount(0), 19, "E1: Top group should be 19 delegations");

    // 5 delegators of candidate 0 undelegate
    _undelegateUsers(10, 15);

    assertEq(
      membershipCouncil.getCandidate(testUsers[0]).delegationCount,
      6, // 5 delegators + self
      "U1: Candidate 0 should have 6 delegations"
    );

    assertEq(
      membershipCouncil.getNumberOfSortedGroups(),
      3,
      "U1: There should be 3 sorted groups after undelegation and candidate 0 merging with candidate 1 for 6 delegations"
    );
    // Verify candidate 0 moved down in ranking
    secondGroup = membershipCouncil.getSortedGroupAtIndex(1);
    assertEq(secondGroup.length, 2, "U1: Second group should have 2 candidates now.");
    assertEq(
      membershipCouncil.getCandidate(testUsers[0]).delegationCount,
      6, // 5 delegators + self
      "U1: Original top candidate should have 6 delegations"
    );
    assertEq(membershipCouncil.getSortedGroupDelegationCount(1), 6, "U1: Second group should be 6 delegations");

    // TODO testusers[2] should enlist again

    // // Final wave: Multiple candidates get same number of delegations
    // vm.prank(testUsers[6]);
    // membershipCouncil.enlistAsCandidate();
    // vm.prank(testUsers[7]);
    // membershipCouncil.enlistAsCandidate();

    // // Give both new candidates 3 delegations each
    // _delegateUsers(testUsers[6], 40, 43);
    // _delegateUsers(testUsers[7], 43, 46);

    // // Add more candidates (users 8-12)
    // for (uint256 i = 8; i < 13; i++) {
    //   vm.prank(testUsers[i]);
    //   membershipCouncil.enlistAsCandidate();
    // }

    // // Third wave: Complex delegation patterns
    // // Some users from previous groups move to new candidates
    // _undelegateUsers(25, 30); // Remove some delegations from top candidate (user 5)
    // _delegateUsers(testUsers[8], 25, 30); // These users now delegate to user 8

    // // New delegations to multiple candidates
    // _delegateUsers(testUsers[9], 46, 52); // 6 delegations to user 9
    // _delegateUsers(testUsers[10], 52, 56); // 4 delegations to user 10

    // // Some users switch their delegation
    // _undelegateUsers(40, 42); // Remove 2 delegations from user 6
    // _delegateUsers(testUsers[11], 40, 42); // These users now delegate to user 11

    // // Verify the new state after third wave
    // topGroup = membershipCouncil.getSortedGroupAtIndex(0);
    // assertEq(
    //   membershipCouncil.getCandidate(testUsers[5]).delegationCount,
    //   11, // 15 - 5 + 1 (self) delegations
    //   "Top candidate should have updated delegation count"
    // );
    // assertEq(
    //   membershipCouncil.getCandidate(testUsers[8]).delegationCount,
    //   6, // 5 + 1 (self) delegations
    //   "New candidate 8 should have correct delegation count"
    // );

    // // Fourth wave: Rapid delegation changes
    // // Quick switches between candidates
    // _undelegateUsers(46, 49); // Remove some from user 9
    // _delegateUsers(testUsers[12], 46, 49); // Move them to user 12
    // _undelegateUsers(47, 48); // One user undelegates
    // _delegateUsers(testUsers[10], 47, 48); // And goes to user 10 instead

    // // Mass movement between candidates
    // _undelegateUsers(30, 35); // Remove several delegations
    // _delegateUsers(testUsers[11], 30, 32); // Split them between user 11
    // _delegateUsers(testUsers[12], 32, 35); // and user 12

    // // Verify complex movements maintained sorting integrity
    // uint256 totalGroups = membershipCouncil.getNumberOfSortedGroups();

    // // Verify delegation counts are properly updated
    // for (uint256 i = 0; i < totalGroups - 1; i++) {
    //   address[] memory currentGroup = membershipCouncil.getSortedGroupAtIndex(i);
    //   address[] memory nextGroup = membershipCouncil.getSortedGroupAtIndex(i + 1);
    //   assertTrue(
    //     membershipCouncil.getCandidate(currentGroup[0]).delegationCount >=
    //       membershipCouncil.getCandidate(nextGroup[0]).delegationCount,
    //     "Groups should be properly sorted by delegation count"
    //   );
    // }

    // // Final state verification
    // assertEq(membershipCouncil.getNumberOfSortedGroups(), 12, "Should have correct number of sorted groups");

    // // Verify no delegation count is negative or invalid
    // for (uint256 i = 0; i < 13; i++) {
    //   if (i >= 8) {
    //     MembershipCouncil.Candidate memory candidate = membershipCouncil.getCandidate(testUsers[i]);
    //     assertTrue(candidate.delegationCount > 0, "All candidates should have at least self-delegation");
    //   }
    // }
  }

  // UTILITY FUNCTIONS

  function _setUpCandidates(uint256 numCandidates) internal {
    for (uint256 i = 0; i < numCandidates; i++) {
      address user = testUsers[i];
      vm.startPrank(user);
      membershipCouncil.enlistAsCandidate();
      vm.stopPrank();
    }
  }

  function _delegateUsers(address candidate, uint256 fromUser, uint256 toUser) internal {
    for (uint256 i = fromUser; i < toUser; i++) {
      vm.prank(testUsers[i]);
      membershipCouncil.delegate(candidate);
    }
  }

  function _undelegateUsers(uint256 fromUser, uint256 toUser) internal {
    for (uint256 i = fromUser; i < toUser; i++) {
      vm.prank(testUsers[i]);
      membershipCouncil.undelegate();
    }
  }
}
