// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

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

  // UTILITY FUNCTIONS

  function _setUpCandidates(uint256 numCandidates) internal {
    for (uint256 i = 0; i < numCandidates; i++) {
      address user = testUsers[i];
      vm.prank(user);
      membershipCouncil.enlistAsCandidate();
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

  function _verifyState(string memory _label, string memory expectedState) internal {
    // Parse the expected state
    string[] memory groups = split(expectedState, ",");
    assertEq(
      groups.length,
      membershipCouncil.getNumberOfSortedGroups(),
      string(abi.encodePacked(_label, " Number of total groups mismatch"))
    );
    for (uint256 i = 0; i < groups.length; i++) {
      string[] memory groupInfo = split(groups[i], ":");
      uint256 expectedDelegationCount = parseUint(groupInfo[0]);
      string[] memory candidates = split(groupInfo[1], "-");

      // Verify the delegation count
      assertEq(
        membershipCouncil.getSortedGroupDelegationCount(i),
        expectedDelegationCount,
        string(abi.encodePacked(_label, " Delegation count mismatch group index ", Strings.toString(i)))
      );

      // Verify the candidates in the group
      address[] memory actualCandidates = membershipCouncil.getSortedGroupAtIndex(i);
      assertEq(
        actualCandidates.length,
        candidates.length,
        string(abi.encodePacked(_label, " Number of candidates mismatch group index ", Strings.toString(i)))
      );

      for (uint256 j = 0; j < candidates.length; j++) {
        uint256 expectedCandidateIndex = parseUint(candidates[j]);
        MembershipCouncil.Candidate memory candidate = membershipCouncil.getCandidate(
          testUsers[expectedCandidateIndex]
        );
        assertEq(
          candidate.delegationCount,
          expectedDelegationCount,
          string(
            abi.encodePacked(
              _label,
              " Candidate/Group delegation count mismatch group index ",
              Strings.toString(i),
              ", candidate ",
              Strings.toString(expectedCandidateIndex)
            )
          )
        );
        bool candidateFound = false;
        for (uint256 k = 0; k < actualCandidates.length; k++) {
          if (actualCandidates[k] == testUsers[expectedCandidateIndex]) {
            candidateFound = true;
            break;
          }
        }
        assertTrue(
          candidateFound,
          string(
            abi.encodePacked(
              _label,
              " Candidate index ",
              Strings.toString(expectedCandidateIndex),
              " not found in group index ",
              Strings.toString(i)
            )
          )
        );
      }
    }
  }

  // Utility function to split a string by a delimiter
  function split(string memory str, string memory delimiter) internal pure returns (string[] memory) {
    bytes memory strBytes = bytes(str);
    bytes memory delimiterBytes = bytes(delimiter);
    uint256[] memory splitIndices = new uint256[](strBytes.length);
    uint256 splitCount = 0;

    for (uint256 i = 0; i < strBytes.length; i++) {
      if (strBytes[i] == delimiterBytes[0]) {
        splitIndices[splitCount] = i;
        splitCount++;
      }
    }

    string[] memory parts = new string[](splitCount + 1);
    uint256 start = 0;
    for (uint256 i = 0; i <= splitCount; i++) {
      uint256 end = (i == splitCount) ? strBytes.length : splitIndices[i];
      bytes memory part = new bytes(end - start);
      for (uint256 j = start; j < end; j++) {
        part[j - start] = strBytes[j];
      }
      parts[i] = string(part);
      start = end + 1;
    }
    return parts;
  }

  // Utility function to parse a string to uint
  function parseUint(string memory str) internal pure returns (uint256) {
    bytes memory b = bytes(str);
    uint256 result = 0;
    for (uint256 i = 0; i < b.length; i++) {
      require(b[i] >= 0x30 && b[i] <= 0x39, "Invalid character in string");
      result = result * 10 + (uint256(uint8(b[i])) - 48);
    }
    return result;
  }
}
