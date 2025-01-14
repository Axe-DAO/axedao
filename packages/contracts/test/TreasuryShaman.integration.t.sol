// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { IBaal } from "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { TreasuryShaman } from "../contracts/baal/TreasuryShaman.sol";
import { ITreasuryShaman } from "../contracts/baal/ITreasuryShaman.sol";
import { MockERC20 } from "../contracts/test/MockERC20.sol";

/**
 * @title TreasuryShamanIntegrationTest
 * @notice Integration test that requires additional setup! The tests assume to be executed
 * against a fork of Sepolia where the Axé DAO and Axé token have been deployed.
 * Start a local anvil node with `anvil --fork-url $SEPOLIA_PROVIDER` before running the tests.
 * Set the `TEST_MODE` environment variable to `integration` before running the tests.
 */
contract TreasuryShamanIntegrationTest is Test {
  // The following addresses are for the Sepolia network
  IBaal baal = IBaal(0x1c3ac998b698206CD2fb22bb422Bf14367470866);
  address owner = 0xEE2ac838C83e5d6bf6Eb1C8A425C007345ACe39E;
  address depositTokenAddress = 0xD44Eb94380bff68a827604fDb2dA7b0A3Ec6Ad0B;
  address depositTokenOwner = 0x7e95A312E398431a26AC266B9215A7DddD5Ea60B;
  uint256 forkBlockNumber = 7224997;

  TreasuryShaman shaman;
  MockERC20 newSwapToken;
  address[] testUsers;
  uint256 constant NUM_TEST_USERS = 5;

  function setUp() public {
    string memory testMode = vm.envOr("TEST_MODE", string("normal"));
    vm.skip(keccak256(abi.encodePacked(testMode)) != keccak256(abi.encodePacked("integration")));
    vm.createSelectFork("http://127.0.0.1:8545", forkBlockNumber);

    // Deploy shaman
    shaman = new TreasuryShaman(
      address(baal),
      depositTokenAddress,
      address(baal), // Use Baal as deposit receiver
      owner
    );

    // Set up shaman permissions
    address[] memory shamans = new address[](1);
    uint256[] memory permissions = new uint256[](1);
    permissions[0] = 2; // Manager
    shamans[0] = address(shaman);
    vm.prank(owner);
    baal.setShamans(shamans, permissions);

    // Deploy new swap token for testing token updates
    newSwapToken = new MockERC20("Axe USD", "AXUSD");

    // Set up test users
    testUsers = new address[](NUM_TEST_USERS);
    for (uint256 i = 0; i < NUM_TEST_USERS; i++) {
      testUsers[i] = address(uint160(0x1000 + i));
      vm.deal(testUsers[i], 100 ether);
    }

    // Give test users some swap tokens
    uint256 amount = 1000 * 10 ** IERC20Metadata(depositTokenAddress).decimals();
    // Set token balances directly
    deal(depositTokenAddress, depositTokenOwner, amount * NUM_TEST_USERS * 2);
    vm.startPrank(depositTokenOwner);
    for (uint256 i = 0; i < NUM_TEST_USERS; i++) {
      IERC20(depositTokenAddress).transfer(testUsers[i], amount);
    }
    vm.stopPrank();
  }

  function test_Deposit() public {
    address user = testUsers[0];
    uint256 depositAmount = 100 * 10 ** IERC20Metadata(depositTokenAddress).decimals();
    uint256 expectedLoot = depositAmount; // 1:1 conversion rate

    uint256 initialLoot = IERC20(baal.lootToken()).balanceOf(user);
    uint256 initialBalance = IERC20(depositTokenAddress).balanceOf(user);

    // Approve and deposit
    vm.startPrank(user);
    IERC20(depositTokenAddress).approve(address(shaman), depositAmount);
    shaman.deposit(depositAmount);
    vm.stopPrank();

    // Verify balances
    assertEq(IERC20(baal.lootToken()).balanceOf(user), initialLoot + expectedLoot, "Incorrect loot minted");
    assertEq(
      IERC20(depositTokenAddress).balanceOf(user),
      initialBalance - depositAmount,
      "Incorrect swap token balance"
    );
  }

  function test_DepositWithDifferentRate() public {
    // Set conversion rate to 2:1 (2 tokens for 1 loot)
    vm.prank(owner);
    shaman.setConversionRate(0.5e18);

    address user = testUsers[1];
    uint256 depositAmount = 100 * 10 ** IERC20Metadata(depositTokenAddress).decimals();
    uint256 expectedLoot = depositAmount / 2; // 2:1 conversion rate

    uint256 initialLoot = IERC20(baal.lootToken()).balanceOf(user);

    // Approve and deposit
    vm.startPrank(user);
    IERC20(depositTokenAddress).approve(address(shaman), depositAmount);
    shaman.deposit(depositAmount);
    vm.stopPrank();

    assertEq(
      IERC20(baal.lootToken()).balanceOf(user),
      initialLoot + expectedLoot,
      "Incorrect loot minted with custom rate"
    );
  }

  function test_SetConversionRate() public {
    uint256 newRate = 2e18;

    vm.prank(owner);
    shaman.setConversionRate(newRate);

    assertEq(shaman.conversionRate(), newRate, "Conversion rate not updated");
  }

  function test_SetDepositToken() public {
    address oldToken = address(shaman.depositToken());

    vm.prank(owner);
    shaman.setDepositToken(address(newSwapToken));

    assertEq(address(shaman.depositToken()), address(newSwapToken), "Swap token not updated");
    assertTrue(oldToken != address(newSwapToken), "Swap token should be different");
  }

  function testRevert_SetConversionRate_NotOwner() public {
    vm.prank(testUsers[0]);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, testUsers[0]));
    shaman.setConversionRate(2e18);
  }

  function testRevert_SetDepositToken_NotOwner() public {
    vm.prank(testUsers[0]);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, testUsers[0]));
    shaman.setDepositToken(address(newSwapToken));
  }

  function testRevert_SetConversionRate_ZeroRate() public {
    vm.prank(owner);
    vm.expectRevert(ITreasuryShaman.InvalidConversionRate.selector);
    shaman.setConversionRate(0);
  }

  function testRevert_SetDepositToken_ZeroAddress() public {
    vm.prank(owner);
    vm.expectRevert(ITreasuryShaman.InvalidDepositToken.selector);
    shaman.setDepositToken(address(0));
  }

  function testRevert_Deposit_ZeroAmount() public {
    vm.prank(testUsers[0]);
    vm.expectRevert(ITreasuryShaman.InsufficientDeposit.selector);
    shaman.deposit(0);
  }

  function testRevert_Deposit_InsufficientAllowance() public {
    address user = testUsers[0];
    uint256 depositAmount = 100 * 10 ** IERC20Metadata(depositTokenAddress).decimals();

    vm.prank(user);
    vm.expectRevert(
      abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(shaman), 0, depositAmount)
    );
    shaman.deposit(depositAmount);
  }
}
