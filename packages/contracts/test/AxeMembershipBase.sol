// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import { AxeMembership, IAxeMembership } from "../contracts/tokens/AxeMembership.sol";
import { MockERC20 } from "./MockERC20.sol";

contract AxeMembershipBase is Test {
  AxeMembership membership;
  MockERC20 paymentToken;
  address[] testUsers;
  uint256 tokenDonationAmount;

  function initiateTestUsers(address _owner, uint256 _numTestUsers) internal {
    testUsers = new address[](_numTestUsers);
    for (uint256 i = 0; i < _numTestUsers; i++) {
      address user = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
      testUsers[i] = user;
      vm.deal(user, 1 ether); // Give each user some ether
      vm.prank(_owner);
      MockERC20(address(paymentToken)).mint(user, 1000 ** 10 * 18); // Mint payment tokens to each user
      vm.startPrank(user);
      paymentToken.approve(address(membership), tokenDonationAmount);
      membership.donate();
      vm.stopPrank();
    }
  }

  function _verifyState(string memory _label, string memory expectedState) internal {
    // Parse the expected state
    string[] memory groups = split(expectedState, ",");
    assertEq(
      groups.length,
      membership.getNumberOfRankedGroups(),
      string(abi.encodePacked(_label, " Number of total groups mismatch"))
    );
    for (uint256 i = 0; i < groups.length; i++) {
      string[] memory groupInfo = split(groups[i], ":");
      uint256 expectedDelegationCount = parseUint(groupInfo[0]);
      string[] memory candidates = split(groupInfo[1], "-");

      // Verify the delegation count
      assertEq(
        membership.getDelegationCountForGroupAtIndex(i),
        expectedDelegationCount,
        string(abi.encodePacked(_label, " Delegation count mismatch group index ", Strings.toString(i)))
      );

      // Verify the candidates in the group
      address[] memory actualCandidates = membership.getRankedGroupAtIndex(i);
      assertEq(
        actualCandidates.length,
        candidates.length,
        string(abi.encodePacked(_label, " Number of candidates mismatch group index ", Strings.toString(i)))
      );

      for (uint256 j = 0; j < candidates.length; j++) {
        uint256 expectedCandidateIndex = parseUint(candidates[j]);
        IAxeMembership.Candidate memory candidate = membership.getCandidate(testUsers[expectedCandidateIndex]);
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

  function parseUint(string memory str) internal pure returns (uint256) {
    bytes memory b = bytes(str);
    uint256 result = 0;
    for (uint256 i = 0; i < b.length; i++) {
      require(b[i] >= 0x30 && b[i] <= 0x39, "Invalid character in string");
      result = result * 10 + (uint256(uint8(b[i])) - 48);
    }
    return result;
  }

  function _setUpCandidates(uint256 numCandidates) internal {
    for (uint256 i = 0; i < numCandidates; i++) {
      address user = testUsers[i];
      vm.prank(user);
      membership.enlistAsCandidate();
    }
  }

  function _delegateUsers(address candidate, uint256 fromUser, uint256 toUser) internal {
    for (uint256 i = fromUser; i < toUser; i++) {
      vm.prank(testUsers[i]);
      membership.delegate(candidate);
    }
  }

  function _undelegateUsers(uint256 fromUser, uint256 toUser) internal {
    for (uint256 i = fromUser; i < toUser; i++) {
      vm.prank(testUsers[i]);
      membership.undelegate();
    }
  }
}
