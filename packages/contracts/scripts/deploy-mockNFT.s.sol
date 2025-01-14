// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";
import { MockNFT } from "../test/MockNFT.sol";

contract Deploy is Script {
  address internal constant owner = 0x6EF543d0Cce1171F696f82cB6f698133037d5b32;
  address internal constant deployer = 0x1fC71A8ED9cF32E2E6EF6F96fB8b16618A4A6fA3;
  string baseTokenURI = "ipfs://QmSA8Chi3TedhAmdSUM88xiH1z8L4tAMqmGu6TFJvFWUtW/haufen-token-art.json";

  function run() external {
    // Get deployment parameters from environment

    vm.startBroadcast();
    require(msg.sender == deployer, "Wrong deployer account!");

    // Deploy MockERC20
    MockNFT token = new MockNFT(owner, 0.01 ether, baseTokenURI);

    vm.stopBroadcast();

    // Log deployment info
    console.log("MockERC20 deployed to:", address(token));
    console.log("Owner:", owner);
    console.log("Base Token URI:", baseTokenURI);
  }
}
