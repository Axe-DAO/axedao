// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

import { AxeMembershipCouncil } from "../contracts/baal/AxeMembershipCouncil.sol";

contract Deploy is Script {
  address internal constant axeDeployer = 0x7e95A312E398431a26AC266B9215A7DddD5Ea60B;

  function run() external {
    address owner = vm.envAddress("DAO_TREASURY_ADDRESS");
    address baal = vm.envAddress("DAO_ADDRESS");
    address membership = vm.envAddress("AXE_MEMBERSHIP_ADDRESS");

    require(owner != address(0), "ENV var for owner is not set!");
    require(baal != address(0), "ENV var for Baal is not set!");
    require(membership != address(0), "ENV var for membership is not set!");
    require(msg.sender == axeDeployer, "Wrong AXE deployer account!");

    console.log("AXE Deployer: %s", msg.sender);
    console.log("Membership: %s", membership);
    console.log("Owner: %s", owner);
    console.log("Baal: %s", baal);

    vm.startBroadcast();
    AxeMembershipCouncil instance = new AxeMembershipCouncil(membership, owner, baal);
    vm.stopBroadcast();

    console.log("Deployed AxeMembershipCouncil to address %s on network %s", address(instance), block.chainid);
  }
}
