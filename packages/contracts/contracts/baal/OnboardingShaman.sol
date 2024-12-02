// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IBaal } from "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import { IMembershipToken } from "../interfaces/IMembershipToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// TODO
// - move delegation logic to MembershipToken
// - for the use case of a single-candidate group moving upward, but not changing position in the sortedGroups array, we can avoid the O(n) shift, just rename the group in the array
// - generally, we can avoid O(n) operations by swapping with nearest neighbor. Deleting/inserting due to deletegate/undelegate is generally only required if the single-candidate joins an existing delegationCount.
// sg[13] = 1 candidateA, sg[15] = 2 candidates.
// userX delegates to candidateA -> rename sg[13] to sg[14]
// userY delegates to candidateA -> add candidate to existing sg[15] and delete sg[14]
// userZ delegates to candidateA -> remove candidate from sg[15], insert new group sq[16] and add candidate
// The same logic applies for undelegation.

contract OnboardingShaman {
  struct Candidate {
    bool available;
    uint256 index;
    uint256 delegationCount;
  }

  mapping(address => Candidate) public candidates;
  mapping(address => address) public delegations;
  mapping(uint256 => address[]) private delegationGroups;
  uint256[] private sortedGroups;

  IMembershipToken public immutable membershipToken;

  constructor(address _membershipToken) {
    membershipToken = IMembershipToken(_membershipToken);
  }

  modifier onlyMember() {
    require(membershipToken.isMember(msg.sender), "Must be a member");
    _;
  }

  /**
   * @notice Enlist the msg.sender as a candidate. The candidate must be a member of the DAO and not already a candidate.
   * Enlisting candidates automatically delegates to themselves to have 1 supporting vote.
   */
  function enlistAsCandidate() external onlyMember {
    require(!candidates[msg.sender].available, "Already enlisted");

    candidates[msg.sender].available = true;
    // Self-delegate for convenience
    if (delegations[msg.sender] == address(0)) {
      delegations[msg.sender] = msg.sender;
      candidates[msg.sender].delegationCount++;
    }
    uint256 groupIndex = candidates[msg.sender].delegationCount;
    candidates[msg.sender].index = delegationGroups[groupIndex].length;
    delegationGroups[groupIndex].push(msg.sender);

    if (delegationGroups[groupIndex].length == 1) {
      insertSortedDelegationCount(groupIndex);
    }
  }

  function resignAsCandidate() external {
    require(candidates[msg.sender].available == true, "Not a candidate");
    candidates[msg.sender].available = false;
    removeCandidateFromGroup(msg.sender, candidates[msg.sender].delegationCount);
  }

  function delegate(address _candidate) external onlyMember {
    require(candidates[_candidate].available, "Candidate not available");

    address previousDelegation = delegations[msg.sender];
    if (previousDelegation != address(0)) {
      uint256 previousCount = candidates[previousDelegation].delegationCount;
      removeCandidateFromGroup(previousDelegation, previousCount);
      candidates[previousDelegation].delegationCount--;
      addCandidateToGroup(previousDelegation, previousCount - 1);
    }

    delegations[msg.sender] = _candidate;
    uint256 newCount = candidates[_candidate].delegationCount + 1;
    removeCandidateFromGroup(_candidate, candidates[_candidate].delegationCount);
    candidates[_candidate].delegationCount = newCount;
    addCandidateToGroup(_candidate, newCount);
  }

  function undelegate() external onlyMember {
    require(delegations[msg.sender] != address(0), "Not delegated");
    address candidate = delegations[msg.sender];
    uint256 currentCount = candidates[candidate].delegationCount;
    removeCandidateFromGroup(candidate, currentCount);
    candidates[candidate].delegationCount--;
    addCandidateToGroup(candidate, currentCount - 1);
    delegations[msg.sender] = address(0);
  }

  function removeCandidateFromGroup(address _candidate, uint256 _groupIndex) internal {
    uint256 index = candidates[_candidate].index;
    address[] storage group = delegationGroups[_groupIndex];
    group[index] = group[group.length - 1];
    candidates[group[index]].index = index;
    group.pop();

    if (group.length == 0) {
      removeSortedDelegationCount(_groupIndex);
    }
  }

  function addCandidateToGroup(address _candidate, uint256 _groupIndex) internal {
    candidates[_candidate].index = delegationGroups[_groupIndex].length;
    delegationGroups[_groupIndex].push(_candidate);

    if (delegationGroups[_groupIndex].length == 1) {
      insertSortedDelegationCount(_groupIndex);
    }
  }

  function insertSortedDelegationCount(uint256 _count) internal {
    // Use binary search to find the correct insertion point
    uint256 left = 0;
    uint256 right = sortedGroups.length;
    while (left < right) {
      uint256 mid = left + (right - left) / 2;
      if (sortedGroups[mid] > _count) {
        left = mid + 1;
      } else {
        right = mid;
      }
    }
    // Insert the count and shift the array
    sortedGroups.push(_count);
    for (uint256 j = sortedGroups.length - 1; j > left; ) {
      sortedGroups[j] = sortedGroups[j - 1];
      unchecked {
        j--;
      }
    }
    sortedGroups[left] = _count;
  }

  function removeSortedDelegationCount(uint256 _count) internal {
    // Use binary search to find the element to remove
    uint256 left = 0;
    uint256 right = sortedGroups.length;
    while (left < right) {
      uint256 mid = left + (right - left) / 2;
      if (sortedGroups[mid] == _count) {
        left = mid;
        break;
      } else if (sortedGroups[mid] > _count) {
        left = mid + 1;
      } else {
        right = mid;
      }
    }
    // Remove the element by shifting the array
    for (uint256 j = left; j < sortedGroups.length - 1; ) {
      sortedGroups[j] = sortedGroups[j + 1];
      unchecked {
        j++;
      }
    }
    sortedGroups.pop();
  }

  function determineCouncil(
    uint256 numberOfCouncilMembers
  ) external view returns (address[] memory) {
    address[] memory council = new address[](numberOfCouncilMembers);
    uint256 councilIndex = 0;

    for (uint256 i = 0; i < sortedGroups.length && councilIndex < numberOfCouncilMembers; ) {
      uint256 groupIndex = sortedGroups[i];
      address[] storage group = delegationGroups[groupIndex];
      uint256 groupLength = group.length;

      if (councilIndex + groupLength <= numberOfCouncilMembers) {
        // Add all members of the group to the council
        for (uint256 j = 0; j < groupLength; ) {
          council[councilIndex] = group[j];
          councilIndex++;
          unchecked {
            j++;
          }
        }
      } else {
        // Create a memory copy of the group
        address[] memory groupCopy = new address[](groupLength);
        for (uint256 c = 0; c < groupLength; ) {
          groupCopy[c] = group[c];
          unchecked {
            c++;
          }
        }

        // Randomly select remaining members from the group copy
        uint256 remainingSlots = numberOfCouncilMembers - councilIndex;
        for (uint256 j = 0; j < remainingSlots; ) {
          uint256 randomIndex = uint256(block.prevrandao) % groupLength;

          // Check if the slot is already used
          if (groupCopy[randomIndex] != address(0)) {
            council[councilIndex] = groupCopy[randomIndex];
            councilIndex++;
            // Mark the index as used by setting it to a special value (e.g., address(0))
            groupCopy[randomIndex] = address(0);
            unchecked {
              j++;
            }
          }
        }
      }
      unchecked {
        i++;
      }
    }

    return council;
  }

  function getCandidate(address _candidate) external view returns (Candidate memory) {
    return candidates[_candidate];
  }
}
