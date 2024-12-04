// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IBaal } from "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IMembershipCouncil } from "../interfaces/IMembershipCouncil.sol";

contract MembershipCouncilShaman is Ownable {
  error MinCouncilSizeRequiredError(uint256 _minSize, uint256 _requestedSize);

  uint256 public constant MIN_COUNCIL_SIZE = 21;
  IMembershipCouncil public immutable membershipCouncil;
  IBaal public immutable baal;
  uint256 public councilSize = MIN_COUNCIL_SIZE;
  uint256 public shareAmount = 1;
  mapping(address => bool) public currentCouncilMembers;
  address[] public currentCouncilList;

  constructor(address _membershipCouncil, address _owner, address _baal) Ownable(_owner) {
    membershipCouncil = IMembershipCouncil(_membershipCouncil);
    baal = IBaal(_baal);
  }

  function setCouncilSize(uint256 _councilSize) external onlyOwner {
    if (_councilSize < MIN_COUNCIL_SIZE)
      revert MinCouncilSizeRequiredError(MIN_COUNCIL_SIZE, _councilSize);
    councilSize = _councilSize;
  }

  function formMembershipCouncil() external {
    IERC20 sharesToken = IERC20(baal.sharesToken());
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
      if (sharesToken.balanceOf(member) <= 1) {
        baal.burnLoot(councilMembers, shareAmounts);
        baal.mintShares(councilMembers, shareAmounts);
      }
      currentCouncilMembers[member] = true;
      currentCouncilList.push(member);

      unchecked {
        i++;
      }
    }
  }

  /**
   * @notice Determine the new council from the sorted delegation ranking in MembershipCouncil.
   * Note that prospective new members who are not yet on the council are required to have at least 1 loot
   * to be converted to shares, otherwise they will not be eligible for the council and will be skipped.
   * @return The new council separated into members who will remain on the council and members who will be added.
   */
  function determineCouncilChanges() internal view returns (address[] memory, address[] memory) {
    address[] memory remainingMembers;
    address[] memory newMembers;
    uint256 remainingMembersIndex = 0;
    uint256 newMembersIndex = 0;
    uint256 councilIndex = 0;
    uint256 numOfGroups = membershipCouncil.getNumberOfDelegationGroups();
    IERC20 lootToken = IERC20(baal.lootToken());

    // Determine new council from sorted delegation ranking in MembershipCouncil
    for (uint256 i = 0; i < numOfGroups && councilIndex < councilSize; ) {
      address[] memory group = membershipCouncil.getDelegationGroup(i);
      address member;

      for (uint256 j = 0; j < group.length && councilIndex < councilSize; ) {
        member = group[j];
        // Candidates must either be on the council already or have at least 1 loot to be converted to shares
        // IMPORTANT if shares ever become transferable, we need to revisit this logic as it could be exploited
        // to receive shares, give them away, and then re-delegate to get back on the council.
        if (currentCouncilMembers[member]) {
          remainingMembers[remainingMembersIndex] = member;
          remainingMembersIndex++;
          councilIndex++;
        } else if (lootToken.balanceOf(member) >= 1) {
          newMembers[newMembersIndex] = member;
          newMembersIndex++;
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
}
