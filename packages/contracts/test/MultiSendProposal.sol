// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract MultiSendProposal is Test {
  function encodeMultiCall(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    address _module
  ) public pure returns (bytes memory) {
    require(targets.length == values.length && values.length == calldatas.length, "Length mismatch");

    bool isModule = _module != address(0);

    bytes memory encodedCalls;
    bytes memory call;

    for (uint256 i = 0; i < targets.length; i++) {
      if (isModule) {
        call = abi.encodeWithSignature(
          "execTransactionFromModuleReturnData(address,uint256,bytes,uint8)",
          targets[i],
          values[i],
          calldatas[i],
          0
        );
      } else {
        call = calldatas[i];
      }

      encodedCalls = abi.encodePacked(
        encodedCalls,
        isModule ? uint8(1) : uint8(0),
        isModule ? _module : targets[i],
        isModule ? uint256(0) : values[i],
        uint256(call.length),
        call
      );
    }

    return abi.encodeWithSignature("multiSend(bytes)", encodedCalls);
  }
}
