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

// - the idea is to make it the decision of the eligible candidate to actively join the council which decreases the chance of a negative impact on ongoing
//   proposals.
// - By letting the candidate claiming decide which current member to remove, we can allow communication between outgoing and incoming council members.
/**
 * @title MembershipCouncilShaman
 * @notice Manages the council formation and seat claims.
 * The shaman upholds the "contract" between the membership community and the membership council to promote/demote members to/from the council.
 * As changes to the council are requested, seats are made available for eligible candidates to claim, if necessary replacing an existing council member.
 * The idea is to make it the decision of the eligible candidate to actively join the council which decreases the chance of a negative impact on ongoing
 * proposal voting.
 */
contract AxeMembershipCouncil is IAxeMembershipCouncil, Ownable, ReentrancyGuard {
  // the loot and shares tokens could be custom implementations, so we'll stay on the safe side with SafeERC20
  using SafeERC20 for IERC20;

  uint256 public constant MIN_COUNCIL_SIZE = 21;
  uint256 public constant FORMATION_COOLDOWN = 24 hours;
  uint256 public lastFormationRequest;
  IAxeMembership public immutable membershipCouncil;
  IBaal public immutable baal;
  uint256 public councilSize = MIN_COUNCIL_SIZE;

  mapping(address => CouncilMember) internal currentCouncil;
  mapping(address => CouncilMember) internal outgoingCouncil;
  mapping(address => CouncilMember) internal incomingCouncil;
  address[] internal currentCouncilList;
  address[] internal outgoingCouncilList;
  address[] internal incomingCouncilList;

  constructor(address _membershipCouncil, address _owner, address _baal) Ownable(_owner) {
    require(_membershipCouncil != address(0), "MembershipCouncilShaman: MembershipCouncil cannot be the zero address");
    require(_baal != address(0), "MembershipCouncilShaman: Baal cannot be the zero address");

    membershipCouncil = IAxeMembership(_membershipCouncil);
    baal = IBaal(_baal);
  }

  /**
   * @notice Claims an available seat in the council and optionally replaces an existing council member.
   * If the council is full, a seat can only be claimed by replacing an existing council member.
   * @param _existingSeat The address of the current council member to replace, if any.
   */
  function claimSeat(address _existingSeat) external nonReentrant {
    address sender = _msgSender();
    if (!incomingCouncil[sender].active) revert InvalidSeatClaim(sender);
    bool isReplacement = _existingSeat != address(0);
    if (isReplacement && !outgoingCouncil[_existingSeat].active) {
      revert InvalidSeatReplacement(sender, _existingSeat);
    }
    if (!isReplacement && currentCouncilList.length >= councilSize) {
      revert OnlyReplacementAllowed(sender);
    }

    IERC20 sharesToken = IERC20(baal.sharesToken());
    IERC20 lootToken = IERC20(baal.lootToken());
    uint256 shareAmount = 1 * 10 ** IERC20Metadata(address(sharesToken)).decimals();

    if (lootToken.balanceOf(sender) < shareAmount) revert InsufficientLoot(sender);
    uint256[] memory shareAmounts = new uint256[](1);
    shareAmounts[0] = shareAmount;
    address[] memory councilMembers = new address[](1);
    councilMembers[0] = sender;

    baal.burnLoot(councilMembers, shareAmounts);
    baal.mintShares(councilMembers, shareAmounts);

    // Remove sender incoming council list
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
    }
  }

  /**
   * @notice Compares the current council with the sorted delegation ranking in MembershipCouncil and
   * makes the seats available for new members.
   * Note that prospective candidates joining the council are required to have at least 1 loot
   * to be converted to shares, otherwise they will not be eligible for the council and will be skipped.
   * This function can only be invoked once every 24 hours to avoid spam.
   */
  function requestCouncilUpdate() external {
    if (block.timestamp - lastFormationRequest < FORMATION_COOLDOWN) revert FormationCooldownError();
    lastFormationRequest = block.timestamp;
    uint256 i;
    uint256 j;

    // clear outgoing and incoming lists
    uint256 length = outgoingCouncilList.length;
    for (i = 0; i < outgoingCouncilList.length; ) {
      address member = outgoingCouncilList[i];
      outgoingCouncil[member].active = false;
      unchecked {
        i++;
      }
    }
    length = incomingCouncilList.length;
    for (i = 0; i < length; ) {
      address member = incomingCouncilList[i];
      incomingCouncil[member].active = false;
      unchecked {
        i++;
      }
    }
    delete outgoingCouncilList;
    delete incomingCouncilList;

    // Create arrays in memory with some initial capacity
    address[] memory remainingMembers;
    uint256 size = councilSize;

    // Use assembly to allocate dynamic memory arrays for remaining  members
    assembly {
      // Array length is stored at the first 32 bytes
      // Store initial capacity after length
      remainingMembers := mload(0x40) // get free memory pointer
      mstore(remainingMembers, 0) // store length (initially 0)
      mstore(add(remainingMembers, 0x20), size) // store capacity
      mstore(0x40, add(remainingMembers, 0x40)) // update free memory pointer
    }

    uint256 councilIndex = 0;
    IERC20 lootToken = IERC20(baal.lootToken());
    uint256 lootThreshold = 1 * 10 ** IERC20Metadata(address(lootToken)).decimals();

    // Determine new council from sorted delegation ranking in MembershipCouncil
    length = membershipCouncil.getNumberOfRankedGroups();
    for (i = 0; i < length && councilIndex < size; ) {
      address[] memory group = membershipCouncil.getRankedGroupAtIndex(i);

      for (j = 0; j < group.length && councilIndex < size; ) {
        address member = group[j];
        if (currentCouncil[member].active) {
          assembly {
            let len := mload(remainingMembers)
            mstore(add(add(remainingMembers, 0x20), mul(len, 0x20)), member)
            mstore(remainingMembers, add(len, 1))
          }
          councilIndex++;
        } else if (lootToken.balanceOf(member) >= lootThreshold) {
          incomingCouncil[member].active = true;
          incomingCouncil[member].index = incomingCouncilList.length;
          incomingCouncilList.push(member);
          councilIndex++;
        }
        unchecked {
          j++;
        }
      }
      unchecked {
        i++;
      }
    }

    // mark outgoing members by comparing currentCouncilList with remainingMembers
    address[] memory removed = _findRemovedCouncilMembers(remainingMembers);
    for (i = 0; i < removed.length; ) {
      address member = removed[i];
      outgoingCouncil[member].active = true;
      outgoingCouncil[member].index = outgoingCouncilList.length;
      outgoingCouncilList.push(member);
      unchecked {
        i++;
      }
    }
  }

  function getCouncilSize() external view override returns (uint256) {
    return currentCouncilList.length;
  }

  function getCouncilMemberAtIndex(uint256 _index) external view override returns (address) {
    return currentCouncilList[_index];
  }

  function getJoiningMembers() external view override returns (address[] memory) {
    return incomingCouncilList;
  }

  function getLeavingMembers() external view override returns (address[] memory) {
    return outgoingCouncilList;
  }

  function setCouncilSize(uint256 _councilSize) external onlyOwner {
    if (_councilSize < MIN_COUNCIL_SIZE) revert InvalidCouncilSize(MIN_COUNCIL_SIZE, _councilSize);
    councilSize = _councilSize;
  }

  /**
   * @notice Returns current council members that are not present in the provided list
   * @param list The list to check against current council
   * @return diff Array of council members not present in the provided list
   */
  function _findRemovedCouncilMembers(address[] memory list) internal view returns (address[] memory diff) {
    // Create bitmap array for the provided list
    uint256[] memory bitmap = new uint256[]((list.length + 255) / 256);
    uint256 resultCount;

    // Mark all addresses from the provided list in bitmap
    unchecked {
      for (uint256 i; i < list.length; ++i) {
        uint256 addressInt = uint256(uint160(list[i]));
        uint256 index = addressInt / 256;
        uint256 bit = addressInt % 256;
        bitmap[index] |= (1 << bit);
      }

      // Count current council members not in bitmap
      address[] memory councilMembers = currentCouncilList;
      uint256 councilLength = councilMembers.length;
      for (uint256 i; i < councilLength; ++i) {
        uint256 addressInt = uint256(uint160(councilMembers[i]));
        uint256 index = addressInt / 256;
        uint256 bit = addressInt % 256;
        if ((bitmap[index] & (1 << bit)) == 0) {
          ++resultCount;
        }
      }

      // Create and populate result array with council members not in list
      diff = new address[](resultCount);
      uint256 diffIndex;

      for (uint256 i; i < councilLength; ++i) {
        uint256 addressInt = uint256(uint160(councilMembers[i]));
        uint256 index = addressInt / 256;
        uint256 bit = addressInt % 256;
        if ((bitmap[index] & (1 << bit)) == 0) {
          diff[diffIndex++] = councilMembers[i];
        }
      }
    }
  }
}
