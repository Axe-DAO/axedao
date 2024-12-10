// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IBaal } from "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IMembershipCouncil } from "../interfaces/IMembershipCouncil.sol";
import { IMembershipCouncilShaman } from "./IMembershipCouncilShaman.sol";

contract MembershipCouncilShaman is IMembershipCouncilShaman, Ownable {
  error MinCouncilSizeRequiredError(uint256 _minSize, uint256 _requestedSize);

  uint256 public constant MIN_COUNCIL_SIZE = 21;
  IMembershipCouncil public immutable membershipCouncil;
  IBaal public immutable baal;
  uint256 public councilSize = MIN_COUNCIL_SIZE;
  mapping(address => bool) public currentCouncilMembers;
  address[] public currentCouncilList;

  constructor(address _membershipCouncil, address _owner, address _baal) Ownable(_owner) {
    require(_membershipCouncil != address(0), "MembershipCouncilShaman: MembershipCouncil cannot be the zero address");
    require(_baal != address(0), "MembershipCouncilShaman: Baal cannot be the zero address");

    membershipCouncil = IMembershipCouncil(_membershipCouncil);
    baal = IBaal(_baal);
  }

  function setCouncilSize(uint256 _councilSize) external onlyOwner {
    if (_councilSize < MIN_COUNCIL_SIZE) revert MinCouncilSizeRequiredError(MIN_COUNCIL_SIZE, _councilSize);
    councilSize = _councilSize;
  }

  function formCouncil() external returns (address[] memory) {
    IERC20 sharesToken = IERC20(baal.sharesToken());
    uint256 shareAmount = 1 * 10 ** IERC20Metadata(address(sharesToken)).decimals();

    (address[] memory remainingMembers, address[] memory newMembers) = determineCouncilChanges();

    // set all current council members to false
    uint256 currentCouncilLength = currentCouncilList.length;
    for (uint256 i = 0; i < currentCouncilLength; ) {
      address member = currentCouncilList[i];
      currentCouncilMembers[member] = false;
      unchecked {
        i++;
      }
    }
    currentCouncilList = new address[](0);

    // add remaining members to the council unchanged
    for (uint256 i = 0; i < remainingMembers.length; ) {
      address member = remainingMembers[i];
      currentCouncilMembers[member] = true;
      currentCouncilList.push(member);
      unchecked {
        i++;
      }
    }

    uint256[] memory shareAmounts = new uint256[](1);
    shareAmounts[0] = shareAmount;
    address[] memory councilMembers = new address[](1);

    for (uint256 i = 0; i < newMembers.length; ) {
      address member = newMembers[i];
      councilMembers[0] = member;
      if (sharesToken.balanceOf(member) <= shareAmount) {
        baal.burnLoot(councilMembers, shareAmounts);
        baal.mintShares(councilMembers, shareAmounts);
      }
      currentCouncilMembers[member] = true;
      currentCouncilList.push(member);

      unchecked {
        i++;
      }
    }

    return currentCouncilList;
  }

  /**
   * @notice Determine the new council from the sorted delegation ranking in MembershipCouncil.
   * Note that prospective new members who are not yet on the council are required to have at least 1 loot
   * to be converted to shares, otherwise they will not be eligible for the council and will be skipped.
   * @return The new council separated into members who will remain on the council and members who will be added.
   */
  function determineCouncilChanges() public view returns (address[] memory, address[] memory) {
    // Create arrays in memory with some initial capacity
    address[] memory remainingMembers;
    address[] memory newMembers;
    uint256 size = councilSize;

    // Use assembly to allocate dynamic memory arrays
    assembly {
      // Array length is stored at the first 32 bytes
      // Store initial capacity after length
      remainingMembers := mload(0x40) // get free memory pointer
      mstore(remainingMembers, 0) // store length (initially 0)
      mstore(add(remainingMembers, 0x20), size) // store capacity
      mstore(0x40, add(remainingMembers, 0x40)) // update free memory pointer

      newMembers := mload(0x40)
      mstore(newMembers, 0) // store length (initially 0)
      mstore(add(newMembers, 0x20), size) // store capacity
      mstore(0x40, add(newMembers, 0x40)) // update free memory pointer
    }

    uint256 councilIndex = 0;
    uint256 numOfGroups = membershipCouncil.getNumberOfSortedGroups();
    IERC20 lootToken = IERC20(baal.lootToken());
    uint256 lootThreshold = 1 * 10 ** IERC20Metadata(address(lootToken)).decimals();

    // Determine new council from sorted delegation ranking in MembershipCouncil
    for (uint256 i = 0; i < numOfGroups && councilIndex < size; ) {
      address[] memory group = membershipCouncil.getSortedGroupAtIndex(i);

      for (uint256 j = 0; j < group.length && councilIndex < size; ) {
        address member = group[j];
        if (currentCouncilMembers[member]) {
          assembly {
            let len := mload(remainingMembers)
            mstore(add(add(remainingMembers, 0x20), mul(len, 0x20)), member)
            mstore(remainingMembers, add(len, 1))
          }
          councilIndex++;
        } else if (lootToken.balanceOf(member) >= lootThreshold) {
          assembly {
            let len := mload(newMembers)
            mstore(add(add(newMembers, 0x20), mul(len, 0x20)), member)
            mstore(newMembers, add(len, 1))
          }
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

    return (remainingMembers, newMembers);
  }

  function getCurrentCouncil() external view override returns (address[] memory) {
    return currentCouncilList;
  }
}
