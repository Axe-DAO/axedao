// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import { IBaal } from "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { AxeMembershipCouncil, IAxeMembershipCouncil } from "../contracts/baal/AxeMembershipCouncil.sol";
import { AxeMembership } from "../contracts/tokens/AxeMembership.sol";
import { MockERC20 } from "./MockERC20.sol";
import { AxeMembershipBase } from "./AxeMembershipBase.sol";
import { MultiSendProposal } from "./MultiSendProposal.sol";

/**
 * @title AxeMembershipCouncilIntegrationTest
 * @notice This test is an integratino test that requires additional setup! The tests assume to be executed
 * against a fork of Sepolia where the Axé DAO and Axé token have been deployed.
 * Start a local anvil node with `anvil --fork-url $SEPOLIA_PROVIDER` before running the tests.
 * Set the `TEST_MODE` environment variable to `integration` before running the tests.
 */
contract AxeMembershipCouncilIntegrationTest is AxeMembershipBase, MultiSendProposal {
  // The following addresses are for the Sepolia network
  IBaal baal = IBaal(0x1c3ac998b698206CD2fb22bb422Bf14367470866);
  address owner = 0xEE2ac838C83e5d6bf6Eb1C8A425C007345ACe39E;
  address recipient = 0x114D5F3904dB2b4635528C08b1687ECB5468EE17;
  address swapTokenAddress = 0xD44Eb94380bff68a827604fDb2dA7b0A3Ec6Ad0B;
  address swapTokenOwner = 0x7e95A312E398431a26AC266B9215A7DddD5Ea60B;
  uint256 forkBlockNumber = 7224997; // Using a fixed block number speeds things up
  uint256 shareThreshold;

  AxeMembershipCouncil shaman;

  function setUp() public {
    string memory testMode = vm.envOr("TEST_MODE", string("normal"));
    vm.skip(keccak256(abi.encodePacked(testMode)) != keccak256(abi.encodePacked("integration")));
    vm.createSelectFork("http://127.0.0.1:8545", forkBlockNumber);

    // Similar setup but with shaman-specific initialization
    paymentToken = MockERC20(swapTokenAddress);
    tokenDonationAmount = 10 ** 10 * IERC20Metadata(swapTokenAddress).decimals();
    shareThreshold = 1 * 10 ** IERC20Metadata(address(baal.sharesToken())).decimals();

    // Deploy the MembershipToken NFT with shaman configuration
    membership = new AxeMembership(
      owner,
      recipient,
      address(paymentToken),
      tokenDonationAmount,
      0.00001 ether,
      "ipfs://Qmb6cxks2ZMfWTXravK5RHf7LYLRYrtgxL14Zg47hFNxjU/quilombo-early-design.json"
    );

    // set up the Shaman
    shaman = new AxeMembershipCouncil(address(membership), owner, address(baal));
    address[] memory shamans = new address[](1);
    uint256[] memory permissions = new uint256[](1);
    permissions[0] = 2; // Manager
    shamans[0] = address(shaman);
    vm.prank(owner);
    baal.setShamans(shamans, permissions);

    // Set up test users
    initiateTestUsers(swapTokenOwner, 700);
    setUpCandidatesAndDelegations();
  }

  function setUpCandidatesAndDelegations() public returns (address[] memory) {
    uint256 numCandidates = 50;
    address[] memory candidates = new address[](numCandidates);
    uint256[] memory loot = new uint256[](numCandidates);
    uint8[50] memory candidatesDelegations = [
      // Original 35 candidates (total: ~250 delegations)
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
      3,
      // 15 new candidates with high delegation counts (~200 delegations)
      15,
      16,
      17,
      14,
      15,
      16,
      17,
      13,
      14,
      15,
      12,
      13,
      14,
      11,
      12
    ];
    uint256 lastIndex = 50; // The 50 candidates all delegate to themselves. Other delegations start from here.
    uint256 topIndex;

    for (uint256 i = 0; i < numCandidates; i++) {
      vm.prank(testUsers[i]);
      membership.enlistAsCandidate();
      loot[i] = shareThreshold;
      topIndex = lastIndex + candidatesDelegations[i];
      _delegateUsers(testUsers[i], lastIndex, topIndex);
      candidates[i] = testUsers[i];
      lastIndex = topIndex;
    }

    _verifyState(
      "SetUp",
      "52:5,44:4,24:3-6-20,18:37-41,17:36-40,16:11-14-35-39-44,15:38-43-47,14:23-42-46,13:10-21-45-49,12:7-16-25-48,11:15,10:24-29,9:17-18-31-32,8:0-9-30,7:8-28,6:27,5:13-26,4:2-34,3:12-19-33,1:1-22"
    );

    // Give all candidates 1 loot
    vm.prank(owner);
    IBaal(baal).mintLoot(candidates, loot);

    return candidates;
  }

  /**
   * @dev Performs a very manual verification of a council update request after the initial setup.
   */
  function test_CouncilUpdateRequest() public {
    address[] memory outgoing = shaman.getLeavingMembers();
    address[] memory incoming = shaman.getJoiningMembers();
    assertEq(outgoing.length, 0, "Expected 0 outgoing candidates at start");
    assertEq(incoming.length, 0, "Expected 0 incoming candidates at start");

    shaman.requestCouncilUpdate();

    outgoing = shaman.getLeavingMembers();
    incoming = shaman.getJoiningMembers();
    assertEq(outgoing.length, 0, "Expected 0 candidates to be removed from the council");
    assertEq(incoming.length, 21, "Expected 21 candidates to be added to the council");

    address[] memory target = new address[](21);
    // 52 votes: candidate 5
    target[0] = testUsers[5];
    // 44 votes: candidate 4
    target[1] = testUsers[4];
    // 24 votes: candidates 3,6,20
    target[2] = testUsers[3];
    target[3] = testUsers[6];
    target[4] = testUsers[20];
    // 18 votes: candidates 37,41
    target[5] = testUsers[37];
    target[6] = testUsers[41];
    // 17 votes: candidates 36,40
    target[7] = testUsers[36];
    target[8] = testUsers[40];
    // 16 votes: candidates 11,14,35,39,44
    target[9] = testUsers[11];
    target[10] = testUsers[14];
    target[11] = testUsers[35];
    target[12] = testUsers[39];
    target[13] = testUsers[44];
    // 15 votes: candidates 38,43,47
    target[14] = testUsers[38];
    target[15] = testUsers[43];
    target[16] = testUsers[47];
    // 14 votes: candidates 23,42,46
    target[17] = testUsers[23];
    target[18] = testUsers[42];
    target[19] = testUsers[46];
    // The lowest group is the 13-vote group and it has multiple candidates
    // Candidates 10,21,45,49 (only need 1 to fill last spot)
    address[] memory lowestGroup = membership.getRankedGroupAtIndex(8); // Group with 13 votes
    // The requestCoucilUpdate() should pick the first candidate from the 13-vote group
    target[20] = lowestGroup[0];

    for (uint256 i = 0; i < target.length; i++) {
      assertTrue(contains(incoming, target[i]), "Expected candidate missing from incoming council");
    }

    // Test uneligibility changes
    address[] memory candidateChanges = new address[](2);
    // Users 11 and 14 are in the 16-vote group, making them eligible, rage-quit, i.e. loose their loot
    candidateChanges[0] = testUsers[11]; // Has 16 votes
    candidateChanges[1] = testUsers[14]; // Has 16 votes
    uint256[] memory lootChanges = new uint256[](2);
    lootChanges[0] = shareThreshold;
    lootChanges[1] = shareThreshold;
    vm.prank(owner);
    baal.burnLoot(candidateChanges, lootChanges);

    vm.warp(block.timestamp + 25 hours);
    shaman.requestCouncilUpdate();
    outgoing = shaman.getLeavingMembers();
    incoming = shaman.getJoiningMembers();

    // The two users who lost their eligibility should not be in the incoming list anymore
    assertFalse(contains(incoming, testUsers[11]), "Expected candidate 11 to be removed from added array");
    assertFalse(contains(incoming, testUsers[14]), "Expected candidate 14 to be removed from added array");

    // The next two users from the 13-vote group who did not make it last time
    // should now be in the incoming list
    assertTrue(
      contains(incoming, lowestGroup[1]),
      "Expected new candidate 1 in incoming list after uneligiblity changes"
    );
    assertTrue(
      contains(incoming, lowestGroup[2]),
      "Expected new candidate 2 in incoming list after uneligiblity changes"
    );
  }

  /**
   * @dev Test claiming seats when the council is empty
   */
  function test_ClaimSeats() public {
    shaman.requestCouncilUpdate();

    uint256 councilSize = shaman.getCouncilSize();
    uint256 numOfSeats = shaman.getJoiningMembers().length;
    assertEq(councilSize, 0, "Expected 0 council members at start");
    assertEq(numOfSeats, 21, "Expected 21 seats to be claimed");

    // Get initial token balances
    IERC20 sharesToken = IERC20(baal.sharesToken());
    IERC20 lootToken = IERC20(baal.lootToken());
    uint256 initialLoot = lootToken.balanceOf(testUsers[0]);
    uint256 initialShares = sharesToken.balanceOf(testUsers[0]);

    // Claim first seat
    vm.startPrank(testUsers[0]);
    shaman.claimSeat(address(0));

    // Verify token conversions
    assertEq(lootToken.balanceOf(testUsers[0]), initialLoot - shareThreshold, "Loot not burned");
    assertEq(sharesToken.balanceOf(testUsers[0]), initialShares + shareThreshold, "Shares not minted");

    // Verify can't claim twice
    vm.expectRevert(abi.encodeWithSelector(IAxeMembershipCouncil.InvalidSeatClaim.selector, address(testUsers[0])));
    shaman.claimSeat(address(0));
    vm.stopPrank();

    councilSize = shaman.getCouncilSize();
    assertEq(councilSize, 1, "Expected 1 council member after claiming seat");

    // Test replacement claim
    vm.startPrank(testUsers[3]);
    address notOnCouncil = address(0xdead);
    vm.expectRevert(
      abi.encodeWithSelector(IAxeMembershipCouncil.InvalidSeatReplacement.selector, testUsers[3], notOnCouncil)
    );
    shaman.claimSeat(notOnCouncil);

    // Get balances before
    initialLoot = lootToken.balanceOf(testUsers[3]);
    initialShares = sharesToken.balanceOf(testUsers[3]);

    // Replace existing member not on outgoing list (council still has many empty seats)
    vm.expectRevert(
      abi.encodeWithSelector(IAxeMembershipCouncil.InvalidSeatReplacement.selector, testUsers[3], testUsers[0])
    );
    shaman.claimSeat(testUsers[0]);

    // Nobody to replace, so claim with 0x0
    shaman.claimSeat(address(0));

    // Verify token conversions for both members
    assertEq(lootToken.balanceOf(testUsers[3]), initialLoot - shareThreshold, "New member loot not burned");
    assertEq(sharesToken.balanceOf(testUsers[3]), initialShares + shareThreshold, "New member shares not minted");

    vm.stopPrank();

    numOfSeats = shaman.getJoiningMembers().length;
    assertEq(numOfSeats, 19, "Expected 19 seats to be claimable after 2 seats claimed");
  }

  /**
   * @dev Test scenarios over a longer period of time with many changes and updates.
   */
  function test_CouncilLifecycle() public {
    // Initial council formation
    shaman.requestCouncilUpdate();
    address[] memory incoming = shaman.getJoiningMembers();
    address[] memory outgoing;
    address[] memory current;

    // Fill council to capacity (21 members)
    for (uint256 i = 0; i < 21; i++) {
      vm.startPrank(incoming[i]);
      shaman.claimSeat(address(0));
      vm.stopPrank();
    }

    assertEq(shaman.getCouncilSize(), 21, "Council should be full");

    // Try to claim when council is full without replacement
    vm.startPrank(testUsers[21]);
    vm.expectRevert(abi.encodeWithSelector(IAxeMembershipCouncil.OnlyReplacementAllowed.selector, testUsers[21]));
    shaman.claimSeat(address(0));
    vm.stopPrank();

    // Wait for cooldown
    vm.warp(block.timestamp + 25 hours);

    // Change delegations to alter rankings
    _delegateUsers(testUsers[25], 100, 150); // Boost ranking

    // Request new council update
    shaman.requestCouncilUpdate();

    // Verify outgoing/incoming lists
    outgoing = shaman.getLeavingMembers();
    incoming = shaman.getJoiningMembers();
    assertTrue(outgoing.length > 0, "Should have members to replace");
    assertTrue(incoming.length > 0, "Should have new members joining");

    // Try replacing non-outgoing member
    vm.startPrank(testUsers[25]);
    vm.expectRevert(
      abi.encodeWithSelector(IAxeMembershipCouncil.InvalidSeatReplacement.selector, testUsers[25], testUsers[0])
    );
    shaman.claimSeat(testUsers[0]);

    // Replace outgoing member
    address outgoingMember = outgoing[0];
    shaman.claimSeat(outgoingMember);
    vm.stopPrank();

    // Verify replacement
    current = shaman.getCurrentMembers();
    assertTrue(contains(current, testUsers[25]), "New member should be in council");
    assertFalse(contains(current, outgoingMember), "Old member should be out of council");

    // Test council size change
    vm.startPrank(owner);
    uint256 newSize = 25;
    shaman.setCouncilSize(newSize);
    assertEq(shaman.councilSize(), newSize, "Council size should be updated");

    // Try setting invalid size
    vm.expectRevert(abi.encodeWithSelector(IAxeMembershipCouncil.InvalidCouncilSize.selector, 21, 20));
    shaman.setCouncilSize(20);
    vm.stopPrank();

    // Test cooldown
    vm.expectRevert(IAxeMembershipCouncil.FormationCooldownError.selector);
    shaman.requestCouncilUpdate();

    assertFalse(shaman.canRequestCouncilUpdate(), "Should not be able to update yet");
    vm.warp(block.timestamp + 25 hours);
    assertTrue(shaman.canRequestCouncilUpdate(), "Should be able to update now");
  }

  /**
   * @dev Test scenarios where the council update is triggered by changes in delegations
   */
  function test_CouncilReplacementScenarios() public {
    // Initial council formation
    shaman.requestCouncilUpdate();
    address[] memory current;
    // Fill council partially (10 members)
    for (uint256 i = 0; i < 10; i++) {
      vm.startPrank(testUsers[i]);
      shaman.claimSeat(address(0));
      vm.stopPrank();
    }

    // Wait and update rankings
    vm.warp(block.timestamp + 25 hours);
    _delegateUsers(testUsers[15], 200, 300); // Boost ranking significantly

    // Request update - some current members should become outgoing due to rank changes
    shaman.requestCouncilUpdate();

    address[] memory outgoing = shaman.getLeavingMembers();
    address[] memory incoming = shaman.getJoiningMembers();

    // Verify state
    assertTrue(outgoing.length > 0, "Should have outgoing members from rank changes");
    assertTrue(incoming.length > 11, "Should have incoming members for empty seats plus replacements");

    // Test multiple replacement scenarios
    vm.startPrank(testUsers[15]);

    // 1. Try replacing with invalid member (not outgoing)
    vm.expectRevert(
      abi.encodeWithSelector(
        IAxeMembershipCouncil.InvalidSeatReplacement.selector,
        testUsers[15],
        testUsers[14] // Not on council
      )
    );
    shaman.claimSeat(testUsers[14]);

    // 2. Successfully replace outgoing member
    address outgoingMember = outgoing[0];
    shaman.claimSeat(outgoingMember);

    // 3. Try replacing same member again with different candidate
    vm.startPrank(testUsers[16]);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAxeMembershipCouncil.InvalidSeatReplacement.selector,
        testUsers[16],
        outgoingMember // Already replaced
      )
    );
    shaman.claimSeat(outgoingMember);

    // 4. Replace another outgoing member
    if (outgoing.length > 1) {
      shaman.claimSeat(outgoing[1]);
    }
    vm.stopPrank();

    // Fill remaining seats
    uint256 remainingSeats = 21 - shaman.getCouncilSize();
    current = shaman.getCurrentMembers();
    for (uint256 i = 0; i < remainingSeats; i++) {
      address candidate = incoming[i];
      if (!contains(current, candidate)) {
        vm.startPrank(candidate);
        shaman.claimSeat(address(0));
        vm.stopPrank();
      }
    }

    // Verify final state
    assertEq(shaman.getCouncilSize(), 21, "Council should be full");
    current = shaman.getCurrentMembers();
    assertTrue(contains(current, testUsers[15]), "Replacement member should be in council");
    assertFalse(contains(current, outgoingMember), "Replaced member should be out");
  }

  /**
   * @dev Test scenarios where the council update is triggered by changes in delegations
   */
  function test_CouncilUpdateScenarios() public {
    // Initial empty council
    shaman.requestCouncilUpdate();
    address[] memory outgoing = shaman.getLeavingMembers();
    address[] memory incoming = shaman.getJoiningMembers();
    address[] memory current;
    assertEq(outgoing.length, 0, "Should have no outgoing members in empty council");
    assertEq(incoming.length, 21, "Should have 21 incoming members for empty council");

    // Fill council partially (10 members)
    for (uint256 i = 0; i < 10; i++) {
      vm.startPrank(incoming[i]);
      shaman.claimSeat(address(0));
      vm.stopPrank();
    }

    // Wait cooldown and update - should only have incoming for remaining seats
    vm.warp(block.timestamp + 25 hours);
    shaman.requestCouncilUpdate();
    outgoing = shaman.getLeavingMembers();
    incoming = shaman.getJoiningMembers();
    assertEq(outgoing.length, 0, "Should have no outgoing during initial filling");
    assertEq(incoming.length, 11, "Should have incoming only for remaining seats");

    // Fill council completely
    for (uint256 i = 0; i < incoming.length; i++) {
      vm.startPrank(incoming[i]);
      shaman.claimSeat(address(0));
      vm.stopPrank();
    }

    // Test no changes scenario - same rankings
    vm.warp(block.timestamp + 25 hours);
    shaman.requestCouncilUpdate();
    outgoing = shaman.getLeavingMembers();
    incoming = shaman.getJoiningMembers();
    assertEq(outgoing.length, 0, "Should have no changes when rankings stay same");
    assertEq(incoming.length, 0, "Should have no changes when rankings stay same");

    // Test partial council replacement - boost some rankings
    vm.warp(block.timestamp + 25 hours);
    _delegateUsers(testUsers[25], 200, 300); // Boost one candidate significantly
    _delegateUsers(testUsers[26], 301, 400); // Boost another candidate
    shaman.requestCouncilUpdate();
    outgoing = shaman.getLeavingMembers();
    incoming = shaman.getJoiningMembers();
    assertEq(incoming.length, outgoing.length, "Should have equal incoming/outgoing for full council");
    assertTrue(outgoing.length > 0, "Should have some replacements");
    assertTrue(outgoing.length < 21, "Should not replace entire council");

    // Test full council replacement - dramatically change all rankings
    vm.warp(block.timestamp + 25 hours);

    // Select candidates not in council (lower ranked ones) to boost
    address[] memory nonCouncilCandidates = new address[](21);
    uint256 idx = 0;
    current = shaman.getCurrentMembers();
    // Fill with candidates that have lower rankings (e.g., ones with 12 or fewer votes)
    for (uint256 i = 0; i < 50 && idx < 21; i++) {
      if (contains(current, testUsers[i])) continue;
      nonCouncilCandidates[idx] = testUsers[i];
      idx++;
    }

    // Boost each candidate by re-delegating existing delegations
    // Use different ranges for each candidate, starting from user 50 (after our candidates)
    // Each range is 50 users wide, and we have space up to user 700
    for (uint256 i = 0; i < 21; i++) {
      uint256 startIdx = 50 + (i * 30); // Each range starts 30 users after the previous
      uint256 endIdx = startIdx + 30; // Each range is 30 users wide
      _delegateUsers(nonCouncilCandidates[i], startIdx, endIdx); // This gives each candidate +30 unique votes
    }

    shaman.requestCouncilUpdate();
    outgoing = shaman.getLeavingMembers();
    incoming = shaman.getJoiningMembers();
    assertEq(incoming.length, outgoing.length, "Should have equal incoming/outgoing for full replacement");
    assertEq(outgoing.length, 21, "Should replace entire council");
  }

  /**
   * @dev Test council size increase scenario since this creates 0x0 addresses in the council
   */
  function test_CouncilSizeIncrease() public {
    // Initial council formation
    shaman.requestCouncilUpdate();
    address[] memory incoming = shaman.getJoiningMembers();
    address[] memory current;
    address[] memory outgoing;

    // Fill council to capacity (21 members)
    for (uint256 i = 0; i < 21; i++) {
      vm.startPrank(incoming[i]);
      shaman.claimSeat(address(0));
      vm.stopPrank();
    }

    // Wait cooldown and increase council size
    vm.warp(block.timestamp + 25 hours);
    vm.prank(owner);
    shaman.setCouncilSize(25);

    // Request update with new size
    shaman.requestCouncilUpdate();
    outgoing = shaman.getLeavingMembers();
    incoming = shaman.getJoiningMembers();

    assertEq(outgoing.length, 0, "Should have no outgoing members when increasing size");
    assertEq(incoming.length, 4, "Should have exactly 4 incoming members for new seats");

    // Verify the incoming members are not already on the council
    current = shaman.getCurrentMembers();
    for (uint256 i = 0; i < incoming.length; i++) {
      assertFalse(contains(current, incoming[i]), "New member should not already be on council");
    }
  }
}
