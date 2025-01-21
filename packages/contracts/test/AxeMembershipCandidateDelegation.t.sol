// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { AxeMembership, IAxeMembership } from "../contracts/tokens/AxeMembership.sol";
import { AxeMembershipCouncil, IAxeMembershipCouncil } from "../contracts/baal/AxeMembershipCouncil.sol";
import { MockERC20 } from "./MockERC20.sol";
import { AxeMembershipBase } from "./AxeMembershipBase.sol";

contract AxeMembershipCandidateDelegationTest is AxeMembershipBase {
  function setUp() public {
    // Deploy the MockERC20 token
    paymentToken = new MockERC20("Payment Token", "PTK");
    tokenDonationAmount = 10 ** 10 * IERC20Metadata(address(paymentToken)).decimals();

    // Deploy the MembershipToken NFT
    membership = new AxeMembership(
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
    membership.enlistAsCandidate();

    // Assert the candidate is enlisted
    IAxeMembership.Candidate memory structCandidate = membership.getCandidate(candidate);
    assertTrue(structCandidate.available, "Candidate should be enlisted");
    assertEq(structCandidate.index, 0, "Candidate should be at index 0");
    assertEq(structCandidate.delegationCount, 1, "Candidate should have 1 delegation");

    assertEq(
      membership.getNumberOfRankedGroups(),
      1,
      "There should be 1 delegation group. Candidate auto self-delegated on enlistment."
    );

    vm.prank(testUsers[1]);
    membership.delegate(candidate);

    assertEq(
      membership.getNumberOfRankedGroups(),
      1,
      "There should still be 1 delegation group after other user delegates to single candidate."
    );

    vm.prank(testUsers[2]);
    membership.enlistAsCandidate();

    assertEq(
      membership.getNumberOfRankedGroups(),
      2,
      "There should be 2 sorted groups after second candidate enlisted."
    );

    vm.prank(candidate);
    membership.resignAsCandidate();
    structCandidate = membership.getCandidate(candidate);
    assertFalse(structCandidate.available);

    assertEq(
      membership.getNumberOfRankedGroups(),
      1,
      "There should be 1 sorted group. One of the candidates resigned."
    );
  }

  function test_DelegateUndelegate() public {
    address delegator = testUsers[0];
    address delegatee = testUsers[1];
    vm.prank(delegatee);
    membership.enlistAsCandidate();

    vm.startPrank(delegator);
    membership.delegate(delegatee);
    assertEq(membership.delegations(delegator), delegatee);

    membership.undelegate();
    assertEq(membership.delegations(delegator), address(0));
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
    membership.resignAsCandidate();

    // Candidate 2's delegators undelegate, except 2
    // The delegatee later re-enlists where the 2 remaining delegations are counted again.
    _undelegateUsers(25, 30);

    // Verify state after resignation of candidate 2 and undelegation of 5 users
    _verifyState("Resign1", "11:0,6:1,1:3-4");

    // New candidate enlists (user 5) and gets more delegations than current top
    vm.prank(testUsers[5]);
    membership.enlistAsCandidate();

    _delegateUsers(testUsers[5], 32, 50); // 18 delegations

    _verifyState("Wave3", "19:5,11:0,6:1,1:3-4");

    // 5 delegators of candidate 0 undelegate
    _undelegateUsers(10, 15);

    _verifyState("Undelegate1", "19:5,6:1-0,1:3-4");

    // Wave Four: Multiple candidates (including candidate 2 again) enlist and get same number of delegations
    vm.prank(testUsers[2]);
    membership.enlistAsCandidate();
    vm.prank(testUsers[6]);
    membership.enlistAsCandidate();
    vm.prank(testUsers[7]);
    membership.enlistAsCandidate();

    // Give new candidates a total of 4 delegations each
    _delegateUsers(testUsers[6], 53, 56);
    _delegateUsers(testUsers[7], 56, 59);
    _delegateUsers(testUsers[2], 59, 60); // Rejoining candidate 2 has 2 delegations from previous wave + self-delegation + 1 new delegation

    // Add 5 more candidates
    for (uint256 i = 8; i < 13; i++) {
      vm.prank(testUsers[i]);
      membership.enlistAsCandidate();
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
    membership.resignAsCandidate();
    membership.undelegate();
    vm.stopPrank();
    _undelegateUsers(32, 33); // Remove 1 delegations from candidate 8
    _delegateUsers(testUsers[3], 33, 35); // 2 delegations from candidate 8 to candidate 3, candidate 8 has 2 other delegations left
    assertEq(membership.getCandidate(testUsers[8]).delegationCount, 2, "Candidate 8 should have 2 delegations left");
    // New delegations to multiple candidates
    _delegateUsers(testUsers[0], 70, 75); // 5 delegations to user 0
    _delegateUsers(testUsers[12], 75, 80); // 5 delegations to user 12
    _delegateUsers(testUsers[4], 80, 88); // 8 delegations to user 4
    _delegateUsers(testUsers[7], 88, 90); // 2 delegations to user 7
    vm.prank(testUsers[11]);
    membership.delegate(testUsers[6]); // candidate 11 delegates their own membership to candidate 6
    vm.prank(testUsers[8]);
    membership.enlistAsCandidate(); // candidate 8 rejoins, gets 1 auto-self-delegation and had 2 delegations left

    // Verify state after Wave Six
    _verifyState("Wave6", "14:5,11:0,9:4,7:9,6:1-12,5:10,4:2-7,3:3-6-8,2:11");
  }

  function _verifyTopCandidates(string memory stage, uint256 limit, address[] memory expected) internal {
    address[] memory topCandidates = membership.getTopCandidates(limit);
    for (uint256 i = 0; i < limit; i++) {
      if (i < expected.length) {
        assertTrue(contains(expected, topCandidates[i]), string.concat("Top candidates mismatch at stage: ", stage));
      } else {
        assertEq(
          topCandidates[i],
          address(0),
          string.concat("Top candidates expected address(0) at index: ", vm.toString(i), ", stage: ", stage)
        );
      }
    }
  }

  function test_GetTopCandidates() public {
    // Setup 5 candidates with different delegation counts
    _setUpCandidates(5);

    // Give them different numbers of delegations
    _delegateUsers(testUsers[0], 10, 21); // 11 delegations
    _delegateUsers(testUsers[2], 21, 27); // 6 delegations
    _delegateUsers(testUsers[4], 27, 30); // 3 delegations

    // Test with different limits
    address[] memory expectedTop3 = new address[](3);
    expectedTop3[0] = testUsers[0]; // 11 delegations
    expectedTop3[1] = testUsers[2]; // 6 delegations
    expectedTop3[2] = testUsers[4]; // 3 delegations
    _verifyTopCandidates("Basic3", 3, expectedTop3);

    // Test with limit 1
    address[] memory expectedTop1 = new address[](1);
    expectedTop1[0] = testUsers[0];
    _verifyTopCandidates("Single", 1, expectedTop1);

    address[] memory expectedOverflow = new address[](5);
    expectedOverflow[0] = testUsers[0];
    expectedOverflow[1] = testUsers[2];
    expectedOverflow[2] = testUsers[4];
    expectedOverflow[3] = testUsers[1];
    expectedOverflow[4] = testUsers[3];
    // Test with limit larger than candidate count
    _verifyTopCandidates("Overflow", 20, expectedOverflow);

    // Test after a resignation
    vm.prank(testUsers[0]);
    membership.resignAsCandidate();

    address[] memory expectedAfterResign = new address[](4);
    expectedAfterResign[0] = testUsers[2]; // 6 delegations
    expectedAfterResign[1] = testUsers[4]; // 3 delegations
    expectedAfterResign[2] = testUsers[1]; // 1 delegation
    expectedAfterResign[3] = testUsers[3]; // 0 delegations
    _verifyTopCandidates("AfterResign", 4, expectedAfterResign);
  }
}
