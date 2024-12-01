// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IBaal } from "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import { IMembershipToken } from "../interfaces/IMembershipToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    uint256 i = 0;
    while (i < sortedGroups.length && sortedGroups[i] > _count) {
      unchecked {
        i++;
      }
    }
    sortedGroups.push(_count);
    for (uint256 j = sortedGroups.length - 1; j > i; j--) {
      sortedGroups[j] = sortedGroups[j - 1];
    }
    sortedGroups[i] = _count;
  }

  function removeSortedDelegationCount(uint256 _count) internal {
    uint256 i = 0;
    while (i < sortedGroups.length && sortedGroups[i] != _count) {
      i++;
    }
    for (uint256 j = i; j < sortedGroups.length - 1; j++) {
      sortedGroups[j] = sortedGroups[j + 1];
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
