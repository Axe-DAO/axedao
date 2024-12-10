// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBaal } from "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";

import "./MembershipCouncilBase.sol";
import { MembershipCouncilShaman } from "../contracts/baal/MembershipCouncilShaman.sol";
import { IMembershipCouncilShaman } from "../contracts/baal/IMembershipCouncilShaman.sol";
import { MockERC20 } from "../contracts/test/MockERC20.sol";
import { MultiSendProposal } from "./MultiSendProposal.sol";

/**
 * @title MembershipCouncilShamanIntegrationTest
 * @notice This test is an integratino test that requires additional setup! The tests assume to be executed
 * against a fork of Sepolia where the Axé DAO and Axé token have been deployed.
 * Start a local anvil node with `anvil --fork-url $SEPOLIA_PROVIDER` before running the tests.
 * Set the `TEST_MODE` environment variable to `integration` before running the tests.
 */
contract MembershipCouncilShamanIntegrationTest is MembershipCouncilBase, MultiSendProposal {
  // The following addresses are for the Sepolia network
  IBaal baal = IBaal(0x1c3ac998b698206CD2fb22bb422Bf14367470866);
  address owner = 0xEE2ac838C83e5d6bf6Eb1C8A425C007345ACe39E;
  address recipient = 0x114D5F3904dB2b4635528C08b1687ECB5468EE17;
  address swapTokenAddress = 0xD44Eb94380bff68a827604fDb2dA7b0A3Ec6Ad0B;
  address swapTokenOwner = 0x7e95A312E398431a26AC266B9215A7DddD5Ea60B;
  uint256 forkBlockNumber = 7224997; // Using a fixed block number speeds things up
  uint256 shareThreshold;

  IMembershipCouncilShaman shaman;

  function setUp() public {
    string memory testMode = vm.envOr("TEST_MODE", string("normal"));
    vm.skip(keccak256(abi.encodePacked(testMode)) != keccak256(abi.encodePacked("integration")));
    vm.createSelectFork("http://127.0.0.1:8545");

    // Similar setup but with shaman-specific initialization
    paymentToken = MockERC20(swapTokenAddress);
    tokenDonationAmount = 10 ** 10 * IERC20Metadata(swapTokenAddress).decimals();
    shareThreshold = 1 * 10 ** IERC20Metadata(address(baal.sharesToken())).decimals();

    // Deploy the MembershipToken NFT with shaman configuration
    membershipCouncil = new MembershipCouncil(
      owner,
      recipient,
      address(paymentToken),
      tokenDonationAmount,
      0.00001 ether,
      "ipfs://Qmb6cxks2ZMfWTXravK5RHf7LYLRYrtgxL14Zg47hFNxjU/quilombo-early-design.json"
    );

    // set up the Shaman
    shaman = new MembershipCouncilShaman(address(membershipCouncil), owner, address(baal));
    address[] memory shamans = new address[](1);
    uint256[] memory permissions = new uint256[](1);
    permissions[0] = 2; // Manager
    shamans[0] = address(shaman);
    vm.prank(owner);
    baal.setShamans(shamans, permissions);

    // Set up test users
    initiateTestUsers(swapTokenOwner, 500);
    setUpCandidatesAndDelegations();
  }

  function setUpCandidatesAndDelegations() public returns (address[] memory) {
    uint256 numCandidates = 35;
    address[] memory candidates = new address[](numCandidates);
    uint256[] memory loot = new uint256[](numCandidates);
    uint8[35] memory candidatesDelegations = [
      7,
      0,
      3,
      23,
      43,
      51,
      23,
      11,
      6,
      7,
      12,
      15,
      2,
      4,
      15,
      10,
      11,
      8,
      8,
      2,
      23,
      12,
      0,
      13,
      9,
      11,
      4,
      5,
      6,
      9,
      7,
      8,
      8,
      2,
      3
    ];
    uint256 lastIndex = 35;
    uint256 topIndex;

    for (uint256 i = 0; i < numCandidates; i++) {
      vm.prank(testUsers[i]);
      membershipCouncil.enlistAsCandidate();
      loot[i] = shareThreshold;
      topIndex = lastIndex + candidatesDelegations[i];
      _delegateUsers(testUsers[i], lastIndex, topIndex);
      candidates[i] = testUsers[i];
      lastIndex = topIndex;
    }

    _verifyState(
      "SetUp",
      "52:5,44:4,24:3-6-20,16:11-14,14:23,13:10-21,12:7-16-25,11:15,10:24-29,9:17-18-31-32,8:0-30-9,7:8-28,6:27,5:13-26,4:2-34,3:12-19-33,1:1-22"
    );

    // Give all candidates 1 loot
    vm.prank(owner);
    IBaal(baal).mintLoot(candidates, loot);

    return candidates;
  }

  function test_CouncilDetermination() public {
    (address[] memory remaining, address[] memory added) = shaman.determineCouncilChanges();
    assertEq(remaining.length, 0, "Expected 0 candidates to be removed from the council");
    assertEq(added.length, 21, "Expected 21 candidates to be added to the council");

    address[] memory target = new address[](21);
    target[0] = testUsers[5];
    target[1] = testUsers[4];
    target[2] = testUsers[3];
    target[3] = testUsers[6];
    target[4] = testUsers[20];
    target[5] = testUsers[11];
    target[6] = testUsers[14];
    target[7] = testUsers[23];
    target[8] = testUsers[10];
    target[9] = testUsers[21];
    target[10] = testUsers[7];
    target[11] = testUsers[16];
    target[12] = testUsers[25];
    target[13] = testUsers[15];
    target[14] = testUsers[24];
    target[15] = testUsers[29];
    target[16] = testUsers[17];
    target[17] = testUsers[18];
    target[18] = testUsers[31];
    target[19] = testUsers[32];
    target[20] = testUsers[0];

    for (uint256 i = 0; i < target.length; i++) {
      assertTrue(contains(added, target[i]), "Expected candidate missing from added array");
    }

    // Make two candidates uneligible and verify outcome
    address[] memory candidateChanges = new address[](2);
    // Users 16 and 17 are the two candidates that will be made uneligible
    candidateChanges[0] = testUsers[16];
    candidateChanges[1] = testUsers[17];
    uint256[] memory lootChanges = new uint256[](2);
    lootChanges[0] = shareThreshold;
    lootChanges[1] = shareThreshold;
    vm.prank(owner);
    baal.burnLoot(candidateChanges, lootChanges);
    (remaining, added) = shaman.determineCouncilChanges();
    // Users 30 and 9 should've moved up the list due to the uneligiblity of users 16 and 17
    assertFalse(contains(added, testUsers[16]), "Expected candidate 16 to be removed from added array");
    assertFalse(contains(added, testUsers[17]), "Expected candidate 17 to be removed from added array");
    target[11] = testUsers[30];
    target[16] = testUsers[9];
    for (uint256 i = 0; i < target.length; i++) {
      assertTrue(contains(added, target[i]), "Expected candidate missing after uneligiblity changes");
    }
  }

  function test_CouncilFormation() public {
    address[] memory current = shaman.getCurrentCouncil();
    assertTrue(current.length == 0, "Expected current council to be empty");
    current = shaman.formCouncil();
    assertTrue(current.length == 21, "Expected current council to be 21");
    for (uint256 i = 0; i < current.length; i++) {
      assertTrue(
        IERC20(baal.sharesToken()).balanceOf(current[i]) == shareThreshold,
        "Expected current council members to have 1 share"
      );
    }
  }

  function contains(address[] memory array, address element) internal pure returns (bool) {
    for (uint256 i = 0; i < array.length; i++) {
      if (array[i] == element) return true;
    }
    return false;
  }
}
