// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { MockERC20 } from "../contracts/test/MockERC20.sol";
import "./MembershipCouncilBase.sol";

contract MembershipCouncilTest is MembershipCouncilBase {
  function setUp() public {
    // Deploy the MockERC20 token
    paymentToken = new MockERC20("Payment Token", "PTK");
    tokenDonationAmount = 10 ** 10 * IERC20Metadata(address(paymentToken)).decimals();

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
    initiateTestUsers(address(this), 100);
  }

  function test_EnlistAndResign() public {
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

  function test_DelegateUndelegate() public {
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
  function test_ComplexDelegationScenario() public {
    // Set up initial candidates (first 5 users become candidates)
    _setUpCandidates(5);
    // Verify initial state (5 self-delegations)
    _verifyState("Initial", "1:0-1-2-3-4");

    // First wave of delegations: 10 members delegate to candidate 0
    _delegateUsers(testUsers[0], 10, 20);

    // Verify candidate 0 is now the top candidate with 11 delegations
    _verifyState("Wave1", "11:0,1:1-2-3-4");

    // Second wave: 5 members delegate to candidate 1 and 7 delegate to candidate 2
    _delegateUsers(testUsers[1], 20, 25);
    _delegateUsers(testUsers[2], 25, 32);

    // Verify state after second wave
    _verifyState("Wave2", "11:0,8:2,6:1,1:3-4");

    // Candidate 2 resigns
    vm.prank(testUsers[2]);
    membershipCouncil.resignAsCandidate();

    // Candidate 2's delegators undelegate, except 2
    // The delegatee later re-enlists where the 2 remaining delegations are counted again.
    _undelegateUsers(25, 30);

    // Verify state after resignation of candidate 2 and undelegation of 5 users
    _verifyState("Resign1", "11:0,6:1,1:3-4");

    // New candidate enlists (user 5) and gets more delegations than current top
    vm.prank(testUsers[5]);
    membershipCouncil.enlistAsCandidate();

    _delegateUsers(testUsers[5], 32, 50); // 18 delegations

    _verifyState("Wave3", "19:5,11:0,6:1,1:3-4");

    // 5 delegators of candidate 0 undelegate
    _undelegateUsers(10, 15);

    _verifyState("Undelegate1", "19:5,6:1-0,1:3-4");

    // Wave Four: Multiple candidates (including candidate 2 again) enlist and get same number of delegations
    vm.prank(testUsers[2]);
    membershipCouncil.enlistAsCandidate();
    vm.prank(testUsers[6]);
    membershipCouncil.enlistAsCandidate();
    vm.prank(testUsers[7]);
    membershipCouncil.enlistAsCandidate();

    // Give new candidates a total of 4 delegations each
    _delegateUsers(testUsers[6], 53, 56);
    _delegateUsers(testUsers[7], 56, 59);
    _delegateUsers(testUsers[2], 59, 60); // Rejoining candidate 2 has 2 delegations from previous wave + self-delegation + 1 new delegation

    // Add 5 more candidates
    for (uint256 i = 8; i < 13; i++) {
      vm.prank(testUsers[i]);
      membershipCouncil.enlistAsCandidate();
    }

    _verifyState("Wave4", "19:5,6:0-1,4:2-6-7,1:3-4-8-9-10-11-12");

    // Fifth wave: Complex delegation patterns
    // Group/Users here: 19:5, 6:0-1, 4:6-7-2, 1:3-4-8-9-10-11-12
    // Some users from previous groups move to new candidates using undelegation and delegation
    _delegateUsers(testUsers[8], 32, 37); // 5 supporters of candidate 5 now delegate to user 8

    // New delegations to multiple candidates
    _delegateUsers(testUsers[9], 60, 66); // 6 delegations to user 9
    _delegateUsers(testUsers[10], 66, 70); // 4 delegations to user 10

    // Some more users undelegate
    _undelegateUsers(53, 55); // Remove 2 delegations from user 6
    // Some users redelegate
    _delegateUsers(testUsers[11], 56, 58); // 2 supporters of candidate 7 now support candidate 11

    // New Counts/Users here: 14:5, 7:9, 6:8-0-1, 5:10, 4:2, 3:11, 2:6-7, 1:3-4-12
    _verifyState("Wave5", "14:5,7:9,6:8-0-1,5:10,4:2,3:11,2:6-7,1:3-4-12");

    // Sixth wave: More complex delegation and various actions
    // Candidate 8 resigns
    vm.startPrank(testUsers[8]);
    membershipCouncil.resignAsCandidate();
    membershipCouncil.undelegate();
    vm.stopPrank();
    _undelegateUsers(32, 33); // Remove 1 delegations from candidate 8
    _delegateUsers(testUsers[3], 33, 35); // 2 delegations from candidate 8 to candidate 3, candidate 8 has 2 other delegations left
    assertEq(
      membershipCouncil.getCandidate(testUsers[8]).delegationCount,
      2,
      "Candidate 8 should have 2 delegations left"
    );
    // New delegations to multiple candidates
    _delegateUsers(testUsers[0], 70, 75); // 5 delegations to user 0
    _delegateUsers(testUsers[12], 75, 80); // 5 delegations to user 12
    _delegateUsers(testUsers[4], 80, 88); // 8 delegations to user 4
    _delegateUsers(testUsers[7], 88, 90); // 2 delegations to user 7
    vm.prank(testUsers[11]);
    membershipCouncil.delegate(testUsers[6]); // candidate 11 delegates their own membership to candidate 6
    vm.prank(testUsers[8]);
    membershipCouncil.enlistAsCandidate(); // candidate 8 rejoins, gets 1 auto-self-delegation and had 2 delegations left

    // Verify state after Wave Six
    _verifyState("Wave6", "14:5,11:0,9:4,7:9,6:1-12,5:10,4:2-7,3:3-6-8,2:11");
  }
}
