// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

import { MembershipToken } from "../contracts/tokens/MembershipToken.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Deploy is Script {
  address internal constant axeDeployer = 0x7e95A312E398431a26AC266B9215A7DddD5Ea60B;

  function run() external {
    address owner = vm.envAddress("AXE_DAO_TREASURY_ADDRESS");
    address receiver = vm.envAddress("AXE_TREASURY_ADDRESS");
    address donationToken = vm.envAddress("AXE_SWAP_TOKEN_ADDRESS");
    uint256 donationAmount = 10 ** 10 * IERC20Metadata(donationToken).decimals(); // should b stable coin $10
    uint256 nativeDonationAmount = 0.0001 ether;

    require(owner != address(0), "ENV var for owner is not set!");
    require(receiver != address(0), "ENV var for receiver is not set!");
    require(donationToken != address(0), "ENV var for donation token is not set!");

    vm.startBroadcast();
    console.log("AXE Deployer: %s", msg.sender);
    require(msg.sender == axeDeployer, "Wrong AXE deployer account!");

    MembershipToken instance = new MembershipToken(
      owner,
      receiver,
      donationToken,
      donationAmount,
      nativeDonationAmount,
      "ipfs://Qmb6cxks2ZMfWTXravK5RHf7LYLRYrtgxL14Zg47hFNxjU/quilombo-early-design.json"
    );

    console.log(
      "Deployed MembershipToken to address %s on network %s",
      address(instance),
      block.chainid
    );

    vm.stopBroadcast();
  }
}
