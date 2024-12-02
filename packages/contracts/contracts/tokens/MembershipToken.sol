// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IMembershipToken } from "../interfaces/IMembershipToken.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MembershipToken is IMembershipToken, ERC721, Ownable {
  address internal donationReceiver;
  address internal donationToken;
  uint256 internal donationAmount;
  uint256 internal nativeDonationAmount;
  uint256 internal memberCount = 0;
  mapping(address => uint256) public members;
  string private baseTokenURI;

  // Delegation accounting
  mapping(address => Candidate) public candidates;
  mapping(address => address) public delegations;
  mapping(uint256 => address[]) private delegationGroups;
  uint256[] private sortedGroups;

  modifier memberOnly() {
    if (!isMember(msg.sender)) revert NotAMemberError();
    _;
  }

  modifier registerNewMember() {
    if (isMember(msg.sender)) revert AlreadyMemberError(msg.sender);
    members[msg.sender] = ++memberCount;
    _;
  }

  constructor(
    address _owner,
    address _donationReceiver,
    address _donationToken,
    uint256 _donationAmount,
    uint256 _nativeDonationAmount,
    string memory _baseTokenURI
  ) ERC721(unicode"Axé DAO Membership", "AXDM") Ownable(_owner) {
    donationReceiver = _donationReceiver;
    donationToken = _donationToken;
    donationAmount = _donationAmount;
    nativeDonationAmount = _nativeDonationAmount;
    baseTokenURI = _baseTokenURI;
  }

  function donate() external override registerNewMember {
    require(
      IERC20(donationToken).transferFrom(msg.sender, donationReceiver, donationAmount),
      "Failed to transfer donation"
    );
    _mint(msg.sender, memberCount);
  }

  function isMember(address _user) public view override returns (bool) {
    return members[_user] != 0;
  }

  receive() external payable registerNewMember {
    _handleNativeDonation();
    _mint(msg.sender, memberCount);
  }

  function _handleNativeDonation() internal {
    if (msg.value < nativeDonationAmount) {
      revert InsufficientDonationError(msg.value, nativeDonationAmount);
    }
    uint256 refundAmount = msg.value - nativeDonationAmount;
    (bool success, ) = donationReceiver.call{ value: nativeDonationAmount }("");
    require(success, "Failed to forward donation");
    if (refundAmount > 0) {
      (bool refundSuccess, ) = msg.sender.call{ value: refundAmount }("");
      require(refundSuccess, "Failed to refund excess amount");
    }
  }

  /**
   * @notice Enlist the msg.sender as a candidate. The candidate must be a member of the DAO and not already a candidate.
   * Enlisting candidates automatically delegates to themselves to have 1 supporting vote.
   */
  function enlistAsCandidate() external memberOnly {
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

  function delegate(address _candidate) external memberOnly {
    require(candidates[_candidate].available, "Candidate not available");
    require(delegations[msg.sender] == address(0), "Already delegated. Please undelegate first.");
    delegations[msg.sender] = _candidate;
    moveCandidate(_candidate, true);
  }

  function undelegate() external memberOnly {
    address candidate = delegations[msg.sender];
    require(candidate != address(0), "No delegation");
    delegations[msg.sender] = address(0);
    moveCandidate(candidate, false);
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

  function _baseURI() internal view override returns (string memory) {
    return baseTokenURI;
  }

  function getMemberCount() external view override returns (uint256) {
    return memberCount;
  }

  function getMemberId(address _user) external view returns (uint256) {
    return members[_user];
  }

  function setTokenDonationAmount(uint256 _donationAmount) external onlyOwner {
    donationAmount = _donationAmount;
  }

  function setNativeDonationAmount(uint256 _nativeDonationAmount) external onlyOwner {
    nativeDonationAmount = _nativeDonationAmount;
  }

  function setDonationReceiver(address _donationReceiver) external onlyOwner {
    donationReceiver = _donationReceiver;
  }

  function setDonationToken(address _donationToken) external onlyOwner {
    donationToken = _donationToken;
  }

  function moveCandidate(address _candidate, bool _up) internal {
    uint256 oldCount = _up
      ? candidates[_candidate].delegationCount++
      : candidates[_candidate].delegationCount--;
    uint256 newCount = _up ? oldCount + 1 : oldCount - 1;
    bool oldDepleted = delegationGroups[oldCount].length == 1;
    bool newMissing = delegationGroups[newCount].length == 0;
    removeCandidateFromGroup(_candidate, oldCount);
    addCandidateToGroup(_candidate, newCount);
    if (oldDepleted && newMissing) {
      renameSortedDelegationCount(oldCount, newCount);
    } else if (oldDepleted && !newMissing) {
      removeSortedDelegationCount(oldCount);
    } else if (!oldDepleted && newMissing) {
      insertSortedDelegationCount(newCount);
    }
  }

  function removeCandidateFromGroup(address _candidate, uint256 _groupIndex) internal {
    uint256 index = candidates[_candidate].index;
    address[] storage group = delegationGroups[_groupIndex];
    group[index] = group[group.length - 1];
    candidates[group[index]].index = index;
    group.pop();
  }

  function addCandidateToGroup(address _candidate, uint256 _groupIndex) internal {
    candidates[_candidate].index = delegationGroups[_groupIndex].length;
    delegationGroups[_groupIndex].push(_candidate);
  }

  function renameSortedDelegationCount(uint256 _oldCount, uint256 _newCount) internal {
    for (uint256 i = 0; i < sortedGroups.length; ) {
      if (sortedGroups[i] == _oldCount) {
        sortedGroups[i] = _newCount;
        break;
      }
      unchecked {
        i++;
      }
    }
  }

  function insertSortedDelegationCount(uint256 _count) internal {
    uint256 insertionIndex = findDelegationCountIndex(_count);
    // Insert the count and shift the array
    sortedGroups.push(_count);
    for (uint256 j = sortedGroups.length - 1; j > insertionIndex; ) {
      sortedGroups[j] = sortedGroups[j - 1];
      unchecked {
        j--;
      }
    }
    sortedGroups[insertionIndex] = _count;
  }

  /**
   * @notice Remove the delegation count from the sortedGroups array.
   * @param _count The delegation count to remove.
   */
  function removeSortedDelegationCount(uint256 _count) internal {
    uint256 deletionIndex = findDelegationCountIndex(_count);
    uint256 lastIndex = sortedGroups.length - 1;
    // Remove the element by shifting the array
    for (uint256 j = deletionIndex; j < lastIndex; ) {
      sortedGroups[j] = sortedGroups[j + 1];
      unchecked {
        j++;
      }
    }
    sortedGroups.pop();
  }

  /**
   * @notice Find the index of the delegation count in the sortedGroups array using binary search.
   * @param _count The delegation count to find.
   * @return The index of the delegation count or the insertion point if not found.
   */
  function findDelegationCountIndex(uint256 _count) internal view returns (uint256) {
    uint256 left = 0;
    uint256 right = sortedGroups.length;
    while (left < right) {
      uint256 mid = left + (right - left) / 2;
      if (sortedGroups[mid] == _count) {
        return mid;
      } else if (sortedGroups[mid] > _count) {
        left = mid + 1;
      } else {
        right = mid;
      }
    }
    return left;
  }
}
