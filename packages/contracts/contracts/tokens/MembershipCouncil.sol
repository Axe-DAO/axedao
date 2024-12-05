// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IMembershipCouncil } from "../interfaces/IMembershipCouncil.sol";

/**
 * @title MembershipToken
 * @notice A ERC721 membership token that allows users to donate to join the DAO and participate in the council elections
 * both as candidates and by delegating their votes to candidates.
 *
 * Members join by donating either a fixed amount of ERC20 tokens or native tokens. The amounts are controlled by the DAO and
 * donations are forwarded to a designated receiver, e.g. a DAO treasury.
 */
contract MembershipCouncil is IMembershipCouncil, ERC721, Ownable {
  address internal donationReceiver;
  address internal donationToken;
  uint256 internal donationAmount;
  uint256 internal nativeDonationAmount;
  uint256 internal memberCount = 0;
  mapping(address => uint256) public members; // tokenId => member address
  string private baseTokenURI;

  /// @notice A mapping from a candidate to their candidacy details.
  mapping(address => Candidate) public candidates;
  /// @notice A mapping from a delegator to their delegatee.
  mapping(address => address) public delegations;
  /// @notice A mapping from delegation count to a list of candidates with that many delegations.
  mapping(uint256 => address[]) private delegationGroups;
  /// @notice The sorted list of delegation counts higher than 0. Highest count first.
  uint256[] private sortedGroups;

  /**
   * @notice Modifier blocking callers who are not members.
   */
  modifier memberOnly() {
    if (!isMember(msg.sender)) revert NotAMemberError();
    _;
  }

  /**
   * @notice Modifier for non-members to automatically register as a member.
   */
  modifier registerNewMember() {
    if (isMember(msg.sender)) revert AlreadyMemberError(msg.sender);
    members[msg.sender] = ++memberCount;
    _;
  }

  /**
   * @notice Constructor for the MembershipToken.
   * @param _owner The owner of the contract who can control adjustable attributes like donation amounts.
   * @param _donationReceiver The address receiving the donations.
   * @param _donationToken The address of the ERC20 token used for donations.
   * @param _donationAmount The amount of ERC20 tokens required to receive a membership NFT.
   * @param _nativeDonationAmount The amount of native tokens required to receive a membership NFT.
   * @param _baseTokenURI The base URI for the membership NFT metadata.
   */
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
   * Enlisting candidates automatically delegate to themselves, if no prior delegation exists. Otherwise, the candidate
   * should undelegate first or can undelegate and then delegate to themselves afterwards.
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
    addCandidateToGroup(msg.sender, groupIndex);

    if (delegationGroups[groupIndex].length == 1) {
      insertSortedGroup(groupIndex);
    }
  }

  function resignAsCandidate() external {
    require(candidates[msg.sender].available == true, "Not a candidate");
    candidates[msg.sender].available = false;
    uint256 groupIndex = candidates[msg.sender].delegationCount;
    removeCandidateFromGroup(msg.sender, groupIndex);

    if (delegationGroups[groupIndex].length == 0) {
      removeSortedGroup(groupIndex);
    }
  }

  function delegate(address _candidate) external memberOnly {
    require(_candidate != address(0), "Cannot delegate to the zero address. Use undelegate.");
    require(candidates[_candidate].available, "Candidate not available");
    require(delegations[msg.sender] == address(0), "Already delegated. Please undelegate first.");
    moveCandidate(_candidate, true);
    delegations[msg.sender] = _candidate;
  }

  function undelegate() external memberOnly {
    address candidate = delegations[msg.sender];
    require(candidate != address(0), "No delegation");
    moveCandidate(candidate, false);
    delegations[msg.sender] = address(0);
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

  /**
   * @notice Get the member ID for a given address.
   * @param _user The address of the member.
   * @return The minted token ID as the member ID.
   */
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

  function getNumberOfSortedGroups() external view returns (uint256) {
    return sortedGroups.length;
  }

  function getSortedGroupAtIndex(uint256 _sortedIndex) external view returns (address[] memory) {
    return delegationGroups[sortedGroups[_sortedIndex]];
  }

  function getSortedGroupDelegationCount(uint256 _sortedIndex) external view returns (uint256) {
    return sortedGroups[_sortedIndex];
  }

  /**
   * @notice Up- or down-votes a candidate depending on the boolean parameter. True for up, false for down.
   * The candidate's delegation count is incremented or decremented by 1 and the candidate is moved between groups accordingly.
   * This function handles the adjustment of the sortedGroups array, if necessary after the move.
   * @param _candidate The candidate to move.
   * @param _up Whether to move the candidate up or down.
   */
  function moveCandidate(address _candidate, bool _up) internal {
    Candidate storage candidate = candidates[_candidate];
    uint256 oldCount = _up ? candidate.delegationCount++ : candidate.delegationCount--;
    // if the candidate resigned, they were already removed from the groups
    if (candidate.available) {
      uint256 newCount = _up ? oldCount + 1 : oldCount - 1;
      bool oldDepleted = removeCandidateFromGroup(_candidate, oldCount) == 0;
      bool newCreated = addCandidateToGroup(_candidate, newCount) == 1;
      if (oldDepleted && newCreated) {
        renameSortedGroup(oldCount, newCount);
      } else if (oldDepleted && !newCreated) {
        removeSortedGroup(oldCount);
      } else if (!oldDepleted && newCreated) {
        insertSortedGroup(newCount);
      }
    }
  }

  // TODO the below internal functions revert on input that threatens the integrity of the sortedGroups array.
  // However, they are strictly not needed as the logic of calling the internal functions should not misuse the internal
  // functions, but better to leave as insurance for now.

  /**
   * @notice Remove a candidate from a delegation group.
   * @param _candidate The candidate to remove.
   * @param _groupIndex The index of the group to remove the candidate from.
   * @return The new length of the group.
   */

  function removeCandidateFromGroup(address _candidate, uint256 _groupIndex) internal returns (uint256) {
    uint256 index = candidates[_candidate].index;
    address[] storage group = delegationGroups[_groupIndex];
    require(index < group.length, "Invalid index");
    require(group[index] == _candidate, "Candidate to remove not found");
    group[index] = group[group.length - 1];
    candidates[group[index]].index = index;
    group.pop();
    return group.length;
  }

  /**
   * @notice Add a candidate to a delegation group.
   * @param _candidate The candidate to add.
   * @param _groupIndex The index of the group to add the candidate to.
   * @return The new length of the group.
   */
  function addCandidateToGroup(address _candidate, uint256 _groupIndex) internal returns (uint256) {
    address[] storage group = delegationGroups[_groupIndex];
    candidates[_candidate].index = group.length;
    group.push(_candidate);
    return group.length;
  }

  function renameSortedGroup(uint256 _oldCount, uint256 _newCount) internal {
    uint256 oldIndex = findSortedGroupsIndex(_oldCount);
    uint256 newIndex = findSortedGroupsIndex(_newCount);
    require(sortedGroups[oldIndex] == _oldCount, "Old Count to rename not found");
    if (newIndex < sortedGroups.length && sortedGroups[newIndex] == _newCount)
      revert("New Count already exists. Cannot rename.");
    sortedGroups[oldIndex] = _newCount;
  }

  function insertSortedGroup(uint256 _count) internal {
    uint256 insertionIndex = findSortedGroupsIndex(_count);
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
  function removeSortedGroup(uint256 _count) internal {
    uint256 deletionIndex = findSortedGroupsIndex(_count);
    require(sortedGroups[deletionIndex] == _count, "Count not found");
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
   * @notice Determins the current or future index of the delegation count in the sortedGroups array using binary search.
   * The calling function needs to determine the context of the returned index, whether to use it for inserting a new delegation count
   * or accessing an existing one.
   * @param _count The delegation count to find.
   * @return The index of the delegation count, if found, or the insertion index in the sorted order, if not found.
   */
  function findSortedGroupsIndex(uint256 _count) internal view returns (uint256) {
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
