// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { IBaal } from "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IAXE } from "../contracts/interfaces/IAXE.sol";
import { MultiSendProposal } from "./MultiSendProposal.sol";

/**
 * @notice Tests the lifecycle of an issuance proposal, i.e. a DAO proposal to
 */
contract ProposalsIntegrationTest is MultiSendProposal {
  event AxeIssued(uint256 _amount);
  event LiquidationSettingsChanged(address router, address swapToken, address pair);

  // The below addresses are available on Sepolia after block 5411000
  address axeToken = 0xaE8F6454fa13EbA1Be4ea60019d1bd34F9D04895;
  address shareholder = 0x6EF543d0Cce1171F696f82cB6f698133037d5b32;
  address dao = 0x1c3ac998b698206CD2fb22bb422Bf14367470866;
  address treasury = 0x114D5F3904dB2b4635528C08b1687ECB5468EE17;
  // address factory = 0xD44Eb94380bff68a827604fDb2dA7b0A3Ec6Ad0B;
  address router = 0xe5c6Bd6750CB9da058F5D5afC61f4058D3968C4D; // e5c6bd6750cb9da058f5d5afc61f4058d3968c4d
  address swapToken = 0xD44Eb94380bff68a827604fDb2dA7b0A3Ec6Ad0B;

  enum ProposalState {
    Unborn /* 0 - can submit */,
    Submitted /* 1 - can sponsor -> voting */,
    Voting /* 2 - can be cancelled, otherwise proceeds to grace */,
    Cancelled /* 3 - terminal state, counts as processed */,
    Grace /* 4 - proceeds to ready/defeated */,
    Ready /* 5 - can be processed */,
    Processed /* 6 - terminal state */,
    Defeated /* 7 - terminal state, yes votes <= no votes, counts as processed */
  }

  function setUp() public {
    string memory testMode = vm.envOr("TEST_MODE", string("normal"));
    vm.skip(keccak256(abi.encodePacked(testMode)) != keccak256(abi.encodePacked("integration")));
    vm.createSelectFork("http://127.0.0.1:8545");
  }

  function test_IssuanceProposal() public {
    // Multisend encoded bytes to issue 500 mil on AXESource at 0xaE8F6454fa13EbA1Be4ea60019d1bd34F9D04895
    bytes[] memory calldatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);
    address[] memory targets = new address[](1);
    calldatas[0] = abi.encodeWithSignature("issue(uint256)", 500_000_000 * (10 ** 18));
    values[0] = 0;
    targets[0] = address(axeToken);

    // Execute the multi-call from the secondary safe
    bytes memory issuanceProposalData = encodeMultiCall(targets, values, calldatas);
    issuanceProposalData = wrapForCustomTreasury(dao, treasury, issuanceProposalData);

    IBaal baal = IBaal(dao);

    vm.startPrank(shareholder);
    uint32 propId = uint32(baal.submitProposal(issuanceProposalData, 0, 16000000, "Show me the money!"));

    // [cancelled, processed, passed, actionFailed]
    bool[4] memory propStatus;

    vm.warp(block.timestamp + 60);
    baal.submitVote(propId, true);
    vm.stopPrank();

    propStatus = baal.getProposalStatus(propId);
    assertFalse(propStatus[2]);

    // jump to process ready
    vm.warp(block.timestamp + baal.votingPeriod() + baal.gracePeriod() + 60);

    (bool success, bytes memory data) = address(baal).call{ value: 0, gas: 5000 }(
      abi.encodeWithSignature("state(uint32)", propId)
    );
    assertTrue(success);
    uint256 decodedState = abi.decode(data, (uint256));
    assertEq(decodedState, uint(ProposalState.Ready));

    console.log("State of prop #%s: %s", propId, decodedState);

    uint256 balanceBefore = IERC20(axeToken).balanceOf(treasury);

    // vm.expectEmit(false, false, false, true);
    // emit AxeIssued(500000000000000000000000000);
    baal.processProposal(propId, issuanceProposalData);

    propStatus = baal.getProposalStatus(propId);
    assertTrue(propStatus[1]);

    uint256 balanceAfter = IERC20(axeToken).balanceOf(treasury);
    assertEq(balanceAfter, balanceBefore + 500_000_000 * (10 ** 18), "Issued amount not in treasury");
  }

  function test_LiquidityProposal() public {
    // Multi-call proposal executed from the treasury to use an existing ERC20 (AxeUSD) and Axé tokens to set up liquidity
    bytes
      memory liquidityProposalData = hex"8d80ff0a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000539001c3ac998b698206cd2fb22bb422bf14367470866000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004e4b3c98bbb000000000000000000000000114d5f3904db2b4635528c08b1687ecb5468ee17000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000444468721a7000000000000000000000000998739bfdaadde7c933b942a68053933098f9eda00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000003848d80ff0a0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000032400d44eb94380bff68a827604fdb2da7b0a3ec6ad0b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044095ea7b3000000000000000000000000ef5ac450a41a39ef8a652c154318b3c8902ed86e00000000000000000000000000000000000000000000003635c9adc5dea0000000ae8f6454fa13eba1be4ea60019d1bd34f9d0489500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044095ea7b3000000000000000000000000ef5ac450a41a39ef8a652c154318b3c8902ed86e000000000000000000000000000000000000000000084595161401484a00000000ae8f6454fa13eba1be4ea60019d1bd34f9d0489500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044cc969acb000000000000000000000000ef5ac450a41a39ef8a652c154318b3c8902ed86e000000000000000000000000d44eb94380bff68a827604fdb2da7b0a3ec6ad0b00ef5ac450a41a39ef8a652c154318b3c8902ed86e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000104e8e33700000000000000000000000000ae8f6454fa13eba1be4ea60019d1bd34f9d04895000000000000000000000000d44eb94380bff68a827604fdb2da7b0a3ec6ad0b000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000003635c9adc5dea0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000114d5f3904db2b4635528c08b1687ecb5468ee1700000000000000000000000000000000000000000000000000000000661de2e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

    vm.startPrank(shareholder);
    IBaal baal = IBaal(dao);
    uint32 propId = 16;
    // uint32 propId = uint32(
    //   baal.submitProposal(liquidityProposalData, 0, 16000000, "Make it rain!")
    // );

    // [cancelled, processed, passed, actionFailed]
    bool[4] memory propStatus;

    // vm.warp(block.timestamp + 60);
    // baal.submitVote(propId, true);

    propStatus = baal.getProposalStatus(propId);
    assertTrue(propStatus[2], "Proposal should have passed");

    // jump to process ready
    // vm.warp(block.timestamp + baal.votingPeriod() + baal.gracePeriod() + 60);

    (bool success, bytes memory data) = address(baal).call{ value: 0, gas: 20000 }(
      abi.encodeWithSignature("state(uint32)", propId)
    );
    assertTrue(success, "Call to state() should work");
    uint256 decodedState = abi.decode(data, (uint256));
    assertEq(decodedState, uint(ProposalState.Ready), "Proposal should be READY");

    // vm.expectEmit(false, false, false, false);

    // emit LiquidationSettingsChanged(router, swapToken, address(0));

    baal.processProposal(propId, liquidityProposalData);

    propStatus = baal.getProposalStatus(propId);
    assertTrue(propStatus[1], "Proposal should be processed");
    assertFalse(propStatus[3], "Proposal should have not failed");

    vm.stopPrank();
  }
}
