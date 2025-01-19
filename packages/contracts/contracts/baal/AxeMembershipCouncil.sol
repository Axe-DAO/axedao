// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IBaal } from "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IAxeMembership } from "../tokens/IAxeMembership.sol";
import { IAxeMembershipCouncil } from "./IAxeMembershipCouncil.sol";

/**
 * @title Axé Membership Council
 * @notice The Axé Membership Council represents the membership community in the Axé DAO's governance process.
 * This contract manages a council with a configurable limit based on Axé Membership delegations and enforces the community's ability to
 * promote/demote members to/from the council.
 * As changes to the council are requested, seats are made available for eligible candidates to claim and, if applicable, replace an existing council member.
 * This allows the individual candidate who's being promoted to be on the council to decide when to actively join. A council member being
 * demoted (replaced) will stay on the council and is able to vote until being replaced. This decreases the likelihood of a negative impact on ongoing
 * proposal voting as the transfer of seats happens at the discretion of the candidates and not at a fixed time.
 * This contract manages the conversion of 1 loot for 1 voting share for claiming a seat and vice versa when a member leaves the council.
 */
contract AxeMembershipCouncil is IAxeMembershipCouncil, Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  uint256 public constant UPDATE_COOLDOWN = 24 hours;
  uint256 public lastFormationRequest;
  IAxeMembership public immutable membership;
  IBaal public immutable baal;
  uint256 public councilLimit = 21; // default limit

  mapping(address => CouncilMember) internal currentCouncil;
  mapping(address => CouncilMember) internal outgoingCouncil;
  mapping(address => CouncilMember) internal incomingCouncil;
  address[] internal currentCouncilList;
  address[] internal outgoingCouncilList;
  address[] internal incomingCouncilList;

  constructor(address _membership, address _owner, address _baal) Ownable(_owner) {
    require(_membership != address(0), "MembershipCouncilShaman: MembershipCouncil cannot be the zero address");
    require(_baal != address(0), "MembershipCouncilShaman: Baal cannot be the zero address");

    membership = IAxeMembership(_membership);
    baal = IBaal(_baal);
  }

  /**
   * @notice Claims an available seat for the caller in the council by replacing the specified outgoing council member.
   * The caller must be on the list of incoming council members and must have one loot to be converted to a voting share.
   * The council member being replaced will have 1 voting share converted back to loot, if they have any.
   * If the council is full, a seat can only be claimed by replacing an existing council member.
   * @param _existingSeat The address of the current council member to replace (optional, required if the council is full)
   */
  function claimSeat(address _existingSeat) external nonReentrant {
    address sender = _msgSender();
    if (!incomingCouncil[sender].active) revert InvalidSeatClaim(sender);
    bool isReplacement = _existingSeat != address(0);
    if (isReplacement && !outgoingCouncil[_existingSeat].active) {
      revert InvalidSeatReplacement(sender, _existingSeat);
    }
    if (!isReplacement && currentCouncilList.length >= councilLimit) {
      revert OnlyReplacementAllowed(sender);
    }

    IERC20 sharesToken = IERC20(baal.sharesToken());
    IERC20 lootToken = IERC20(baal.lootToken());
    uint256 shareAmount = 1 * 10 ** IERC20Metadata(address(sharesToken)).decimals();

    if (lootToken.balanceOf(sender) < shareAmount) revert InsufficientLoot(sender);

    // arrays for burning/minting shares
    uint256[] memory shareAmounts = new uint256[](1);
    address[] memory shareRecipients = new address[](1);
    // the share amount is the same for both the leaving and joining member, mint and burn
    shareAmounts[0] = shareAmount;

    // Remove sender from incoming council list
    uint256 targetIndex = incomingCouncil[sender].index;
    uint256 lastIndex = incomingCouncilList.length - 1;
    if (targetIndex != lastIndex) {
      address lastMember = incomingCouncilList[lastIndex];
      incomingCouncilList[targetIndex] = lastMember;
      incomingCouncil[lastMember].index = targetIndex;
    }
    incomingCouncilList.pop();
    incomingCouncil[sender].active = false;

    // Update current council
    currentCouncil[sender].active = true;
    if (!isReplacement) {
      currentCouncil[sender].index = currentCouncilList.length;
      currentCouncilList.push(sender);
    } else {
      // Remove existing seat from outgoing council list
      targetIndex = outgoingCouncil[_existingSeat].index;
      lastIndex = outgoingCouncilList.length - 1;
      if (targetIndex != lastIndex) {
        address lastOutgoing = outgoingCouncilList[lastIndex];
        outgoingCouncilList[targetIndex] = lastOutgoing;
        outgoingCouncil[lastOutgoing].index = targetIndex;
      }
      outgoingCouncilList.pop();
      outgoingCouncil[_existingSeat].active = false;

      // Swap index old member with new member in current council
      currentCouncil[sender].index = currentCouncil[_existingSeat].index;
      currentCouncilList[currentCouncil[_existingSeat].index] = sender;

      // Handle burn/mint for the leaving member
      shareRecipients[0] = _existingSeat;
      baal.burnShares(shareRecipients, shareAmounts);
      baal.mintLoot(shareRecipients, shareAmounts);
    }

    // Handle burn/mint for the claiming candidate
    shareRecipients[0] = sender;
    baal.burnLoot(shareRecipients, shareAmounts);
    baal.mintShares(shareRecipients, shareAmounts);

    emit SeatClaimed(sender, _existingSeat);
  }

  /**
   * @notice Compares the current council with the delegation ranking in AxeMembershipCouncil and
   * refreshes the "incoming" and "outgoing" council lists which determine available seats for claiming.
   * Prospective candidates in the top ranking *are required* to have at least 1 loot at the
   * time of this request, otherwise they are not eligible and will be skipped.
   * The function also removes (makes their seats available) any council members that no longer have
   * enough voting shares to be on the council, most likely due to a rage-quit.
   * This function can only be invoked once every 24 hours to avoid spam.
   */
  function requestCouncilUpdate() external {
    if (block.timestamp - lastFormationRequest < UPDATE_COOLDOWN) revert UpdateCooldownInEffect();
    lastFormationRequest = block.timestamp;

    IERC20 sharesToken = IERC20(baal.sharesToken());
    IERC20 lootToken = IERC20(baal.lootToken());
    uint256 shareAmount = 1 * 10 ** IERC20Metadata(address(sharesToken)).decimals();
    uint256 lootThreshold = 1 * 10 ** IERC20Metadata(address(lootToken)).decimals();

    delete outgoingCouncilList;
    delete incomingCouncilList;

    // Store top ranked candidates in memory
    address[] memory topCandidates = new address[](councilLimit);
    uint256 candidateCount = 0;
    uint256 groupIndex = 0;
    address member;
    uint256 currentCouncilLength = currentCouncilList.length;

    // 1. First check for rage-quits
    for (uint256 i; i < currentCouncilLength; ) {
      member = currentCouncilList[i];
      // have to check for address(0) because the council can be empty or council size was increased
      if (member != address(0) && sharesToken.balanceOf(member) < shareAmount) {
        currentCouncil[member].active = false;
        outgoingCouncil[member].active = true;
        outgoingCouncil[member].index = outgoingCouncilList.length;
        outgoingCouncilList.push(member);
      }
      unchecked {
        i++;
      }
    }

    // 2. Fill council slots from top ranked candidates
    uint256 groupCount = membership.getNumberOfRankedGroups();
    uint256 targetCouncilSize = councilLimit;
    while (candidateCount < targetCouncilSize && groupIndex < groupCount) {
      address[] memory group = membership.getRankedGroupAtIndex(groupIndex);

      for (uint256 j; j < group.length && candidateCount < targetCouncilSize; ) {
        address candidate = group[j];

        if (currentCouncil[candidate].active) {
          // Current member stays
          topCandidates[candidateCount] = candidate;
          candidateCount++;
        } else if (lootToken.balanceOf(candidate) >= lootThreshold) {
          // New member joins
          topCandidates[candidateCount] = candidate;
          incomingCouncil[candidate].active = true;
          incomingCouncil[candidate].index = incomingCouncilList.length;
          incomingCouncilList.push(candidate);
          candidateCount++;
        }
        unchecked {
          j++;
        }
      }
      unchecked {
        groupIndex++;
      }
    }

    // 3. Any remaining active council members not in top candidates go to outgoing
    for (uint256 i; i < currentCouncilLength; ) {
      member = currentCouncilList[i];
      // have to check for address(0) because there could be empty seats
      if (member != address(0)) {
        bool found = false;
        for (uint256 j; j < candidateCount; ) {
          if (topCandidates[j] == member) {
            found = true;
            break;
          }
          unchecked {
            j++;
          }
        }

        if (!found) {
          outgoingCouncil[member].active = true;
          outgoingCouncil[member].index = outgoingCouncilList.length;
          outgoingCouncilList.push(member);
        }
      }
      unchecked {
        i++;
      }
    }

    emit CouncilUpdateRequested(currentCouncilList.length, incomingCouncilList.length, outgoingCouncilList.length);
  }

  /**
   * @notice Returns the current size of the council (number of members).
   * @return The current size of the council.
   */
  function getCurrentCouncilSize() external view override returns (uint256) {
    return currentCouncilList.length;
  }

  /**
   * @notice Returns the address of the council member at the specified index.
   * @param _index The index of the council member.
   * @return The address of the council member.
   */
  function getCouncilMemberAtIndex(uint256 _index) external view override returns (address) {
    return currentCouncilList[_index];
  }

  /**
   * @notice Returns the list of all current council members.
   * @return The list of all current council members.
   */
  function getCurrentMembers() external view override returns (address[] memory) {
    return currentCouncilList;
  }

  /**
   * @notice Returns the list of all members that are eligible to join the council.
   * This list corresponds to the claimable seats in the council.
   * @return The list of all members that are eligible to join the council.
   */
  function getJoiningMembers() external view override returns (address[] memory) {
    return incomingCouncilList;
  }

  /**
   * @notice Returns the list of all members that are leaving the council.
   * This list corresponds to the seats being replaced on the council.
   * @return The list of all members that are leaving the council.
   */
  function getLeavingMembers() external view override returns (address[] memory) {
    return outgoingCouncilList;
  }

  /**
   * @notice Returns whether the council update can be requested, i.e. if the cooldown has passed.
   * @return Whether the council update can be requested.
   */
  function canRequestCouncilUpdate() external view override returns (bool) {
    return block.timestamp - lastFormationRequest > UPDATE_COOLDOWN;
  }

  /**
   * @notice Increases the limit of the council and therefore expands the council to have more members.
   * Decreasing the limit is not allowed to avoid having to remove members from the council.
   * @param _newLimit The new limit of the council.
   */
  function increaseCouncilLimit(uint256 _newLimit) external onlyOwner {
    if (_newLimit <= councilLimit) {
      revert InvalidCouncilLimit(councilLimit, _newLimit);
    }
    // Create new array with new size and copy over existing members
    address[] memory newList = new address[](_newLimit);
    for (uint256 i = 0; i < currentCouncilList.length; i++) {
      newList[i] = currentCouncilList[i];
    }
    currentCouncilList = newList;
    councilLimit = _newLimit;
    emit CouncilLimitIncreased(_newLimit);
  }
}
