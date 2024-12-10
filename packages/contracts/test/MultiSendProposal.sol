// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract MultiSendProposal is Test {
  function encodeMultiCall(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas
  ) public pure returns (bytes memory) {
    require(targets.length == values.length && values.length == calldatas.length, "Length mismatch");

    bytes memory encodedCalls;

    for (uint256 i = 0; i < targets.length; i++) {
      encodedCalls = abi.encodePacked(encodedCalls, uint8(0), targets[i], values[i], calldatas[i].length, calldatas[i]);
    }

    return abi.encodeWithSignature("multiSend(bytes)", encodedCalls);
  }

  // New function to wrap existing multiSend bytes with custom treasury execution
  function wrapForCustomTreasury(
    address mainTreasury,
    address secondaryTreasury,
    bytes memory innerMultiSend
  ) public pure returns (bytes memory) {
    // First wrap the multiSend in execTransactionFromModule call
    bytes memory execFromModule = abi.encodeWithSignature(
      "execTransactionFromModule(address,uint256,bytes,uint8)",
      secondaryTreasury, // target - the secondary treasury
      0, // no ETH value
      innerMultiSend, // the multiSend data
      1 // operation - delegatecall
    );

    // Then wrap that in executeAsBaal
    bytes memory executeAsBaal = abi.encodeWithSignature(
      "executeAsBaal(address,uint256,bytes)",
      mainTreasury, // _to - the main treasury
      0, // _value - no ETH
      execFromModule // _data - the execTransactionFromModule call
    );

    return executeAsBaal;
  }
}
