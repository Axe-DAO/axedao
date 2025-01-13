// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IMembershipCouncil } from "../interfaces/IMembershipCouncil.sol";

/**
 * @title MembershipToken
 * @notice A ERC721 membership token that allows users to donate to join the DAO and participate in the council elections
 * both as candidates and by delegating their votes to candidates.
 *
 * Users become members by donating either a fixed amount of ERC20 tokens or native tokens. The amounts are controlled by the DAO and
 * donations are forwarded to a designated receiver, e.g. a DAO treasury.
 *
 * Members can enlist/resign as candidates for the Membership Council. Any member, including enlisted candidates, can delegate their
 * membership to a candidate of their choice. The contract keeps track of delegations and candidate availability and maintains a sorted
 * list of delegation counts to allow for efficient querying of the top candidates.
 */
contract MembershipCouncil is IMembershipCouncil, ERC721, Ownable, ReentrancyGuard {
  // The donation token could be a custom implementation, so we'll stay on the safe side with SafeERC20
  using SafeERC20 for IERC20;

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
    if (!isMember(_msgSender())) revert NotAMemberError();
    _;
  }

  /**
   * @notice Modifier for non-members to automatically register as a member.
   */
  modifier registerNewMember() {
    address sender = _msgSender();
    if (isMember(sender)) revert AlreadyMemberError(sender);
    members[sender] = ++memberCount;
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

  function donate() external override registerNewMember nonReentrant {
    address sender = _msgSender();
    IERC20(donationToken).safeTransferFrom(sender, donationReceiver, donationAmount);
    _mint(sender, memberCount);
    emit ERC20DonationReceived(sender, donationAmount);
  }

  receive() external payable registerNewMember nonReentrant {
    _handleNativeDonation();
    _mint(_msgSender(), memberCount);
  }

  function isMember(address _user) public view override returns (bool) {
    return members[_user] != 0;
  }

  /**
   * @notice Enlist the msg.sender as a candidate. The candidate must be a member of the DAO and not already a candidate.
   * Enlisting candidates automatically delegate to themselves, if no prior delegation exists. Otherwise, the candidate
   * should undelegate first or can undelegate and then delegate to themselves afterwards.
   */
  function enlistAsCandidate() external memberOnly {
    address sender = _msgSender();
    require(!candidates[sender].available, "Already enlisted");

    candidates[sender].available = true;
    // Self-delegate for convenience
    if (delegations[sender] == address(0)) {
      delegations[sender] = sender;
      candidates[sender].delegationCount++;
    }
    uint256 groupIndex = candidates[sender].delegationCount;
    addCandidateToGroup(sender, groupIndex);
    if (delegationGroups[groupIndex].length == 1) {
      insertSortedGroup(groupIndex);
    }
    emit CandidateEnlisted(sender);
  }

  function resignAsCandidate() external {
    address sender = _msgSender();
    require(candidates[sender].available == true, "Not a candidate");
    candidates[sender].available = false;
    uint256 groupIndex = candidates[sender].delegationCount;
    removeCandidateFromGroup(sender, groupIndex);
    if (delegationGroups[groupIndex].length == 0) {
      removeSortedGroup(groupIndex);
    }
    emit CandidateResigned(sender);
  }

  function delegate(address _candidate) external memberOnly {
    address sender = _msgSender();
    require(_candidate != address(0), "Cannot delegate to the zero address. Use undelegate.");
    require(candidates[_candidate].available, "Candidate not available");
    address currentDelegate = delegations[sender];
    if (currentDelegate == _candidate) return;
    if (currentDelegate != address(0)) {
      moveCandidate(currentDelegate, false);
    }
    moveCandidate(_candidate, true);
    delegations[sender] = _candidate;
    emit VoteDelegated(sender, _candidate);
  }

  function undelegate() external memberOnly {
    address sender = _msgSender();
    address candidate = delegations[sender];
    require(candidate != address(0), "No delegation");
    moveCandidate(candidate, false);
    delegations[sender] = address(0);
    emit VoteUndelegated(sender);
  }

  /**
   * @notice Get the candidate details for the given candidate address.
   * @param _candidate The address of the candidate.
   * @return The candidate details.
   */
  function getCandidate(address _candidate) external view returns (Candidate memory) {
    return candidates[_candidate];
  }

  /**
   * @notice The base URI for the membership NFT metadata.
   * @return The base URI.
   */
  function _baseURI() internal view override returns (string memory) {
    return baseTokenURI;
  }

  /**
   * @notice The token URI for the membership NFT metadata.
   * @return The token URI.
   */
  function tokenURI(uint256 /* tokenId */) public view override returns (string memory) {
    return _baseURI();
  }

  /**
   * @notice Get the number of members.
   * @return The number of members = the number of minted NFTs.
   */
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

  /**
   * @notice Get the donation amount required to mint a membership NFT.
   * @return The donation amount.
   */
  function getTokenDonationAmount() external view override returns (uint256) {
    return donationAmount;
  }

  /**
   * @notice Set the donation amount required to mint a membership NFT.
   * @param _donationAmount The new donation amount.
   */
  function setTokenDonationAmount(uint256 _donationAmount) external onlyOwner {
    donationAmount = _donationAmount;
  }

  /**
   * @notice Get the native donation amount required to mint a membership NFT.
   * @return The donation amount.
   */
  function getNativeDonationAmount() external view override returns (uint256) {
    return nativeDonationAmount;
  }

  /**
   * @notice Set the native donation amount required to mint a membership NFT.
   * @param _nativeDonationAmount The new donation amount.
   */
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

  function _handleNativeDonation() internal {
    address sender = _msgSender();
    if (msg.value < nativeDonationAmount) {
      revert InsufficientDonationError(msg.value, nativeDonationAmount);
    }
    uint256 refundAmount = msg.value - nativeDonationAmount;
    (bool success, ) = donationReceiver.call{ value: nativeDonationAmount }("");
    require(success, "Failed to forward donation");
    if (refundAmount > 0) {
      (bool refundSuccess, ) = sender.call{ value: refundAmount }("");
      require(refundSuccess, "Failed to refund excess amount");
    }
    emit NativeDonationReceived(sender, nativeDonationAmount);
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
