// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

import { TreasuryShaman } from "../contracts/baal/TreasuryShaman.sol";

contract Deploy is Script {
  address internal constant axeDeployer = 0x7e95A312E398431a26AC266B9215A7DddD5Ea60B;

  function run() external {
    address owner = vm.envAddress("DAO_TREASURY_ADDRESS");
    address baal = vm.envAddress("DAO_ADDRESS");
    address depositToken = vm.envAddress("AXE_SWAP_TOKEN_ADDRESS");
    address depositReceiver = vm.envAddress("DAO_TREASURY_ADDRESS");

    require(owner != address(0), "ENV var for owner is not set!");
    require(baal != address(0), "ENV var for Baal is not set!");
    require(depositToken != address(0), "ENV var for deposit token is not set!");
    require(depositReceiver != address(0), "ENV var for deposit receiver is not set!");
    require(msg.sender == axeDeployer, "Wrong AXE deployer account!");

    console.log("AXE Deployer: %s", msg.sender);
    console.log("Baal: %s", baal);
    console.log("Owner: %s", owner);
    console.log("Deposit Token: %s", depositToken);
    console.log("Deposit Receiver: %s", depositReceiver);

    vm.startBroadcast();
    TreasuryShaman instance = new TreasuryShaman(baal, depositToken, depositReceiver, owner);
    vm.stopBroadcast();

    console.log("Deployed TreasuryShaman to address %s on network %s", address(instance), block.chainid);
  }
}
