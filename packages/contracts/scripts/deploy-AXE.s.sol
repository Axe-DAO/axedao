// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";
import { ICREATE3Factory } from "create3-factory/ICREATE3Factory.sol";

import { AXESource } from "../contracts/tokens/AXESource.sol";
import { AXE } from "../contracts/tokens/AXE.sol";

contract Deploy is Script {
  address internal constant create3Factory = 0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1;
  address internal constant axeDeployer = 0x7e95A312E398431a26AC266B9215A7DddD5Ea60B;
  address internal constant axeTargetAddress = 0xaE8F6454fa13EbA1Be4ea60019d1bd34F9D04895;
  string internal constant _LADAINHA =
    unicode"Iê Maior é Deus - Maior é Deus, pequeno sou eu - (Tudo) O que eu tenho foi Deus que me deu - (Tudo) O que eu tenho foi Deus que me deu - Na roda da capoeira (Hahá!) Grande e pequeno sou eu - Camará …";

  function run() external {
    address treasury = vm.envAddress("AXE_TREASURY_ADDRESS");
    address founder = vm.envAddress("FOUNDER_ADDRESS");

    require(treasury != address(0), "ENV var for treasury is not set!");
    require(founder != address(0), "ENV var for founder is not set!");

    console.log("AXE Deployer: %s", msg.sender);
    require(msg.sender == axeDeployer, "Wrong AXE deployer account!");

    vm.startBroadcast();
    // Gnosis + Sepolia are the home chains where AXESource must be deployed
    bool sourceChain = block.chainid == 100 || block.chainid == 11155111;
    // The creation of AXE is salted with a ladainha and the msg.sender
    bytes32 _salt = keccak256(abi.encodePacked(_LADAINHA, msg.sender));
    bytes memory _creation = sourceChain ? type(AXESource).creationCode : type(AXE).creationCode;
    bytes memory _initParams = sourceChain ? abi.encode(treasury, founder) : abi.encode(treasury);
    bytes memory _bytecode = abi.encodePacked(_creation, _initParams);

    address instance = ICREATE3Factory(create3Factory).deploy(_salt, _bytecode);
    require(instance == axeTargetAddress, "CREATE3 did not generate the expected target address!");

    vm.stopBroadcast();

    string memory axeType = sourceChain ? "AXESource" : "AXE";
    console.log("Deployed %s to address %s on network %s", axeType, instance, block.chainid);
  }
}
