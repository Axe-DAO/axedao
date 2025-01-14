// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";

import "../contracts/tokens/IAXE.sol";
import "../contracts/tokens/AXESource.sol";
import "../contracts/utils/Governable.sol";

/**
 * @notice Test for AXESource token
 */
contract AXETest is Test {
  uint256 constant VESTING_AMOUNT = 50_000_000 * 10 ** 18;
  uint64 constant VESTING_DURATION = 94_608_000; // 3 years
  AXESource token;
  VestingWallet vestingWallet;
  address owner;
  address addr1;
  address addr2;

  function setUp() public {
    owner = address(this);
    addr1 = address(0x1);
    addr2 = address(0x2);

    token = new AXESource(owner, owner);
    vestingWallet = VestingWallet(payable(token.vestingWallet()));
  }

  function testDeployment() public {
    assertEq(token.name(), unicode"Axé");
    assertEq(token.symbol(), unicode"AXÉ");
    assertEq(token.totalSupply(), VESTING_AMOUNT);
    assertEq(token.MAX_SUPPLY(), 9_911_238_945 * 10 ** 18);
    assertEq(token.governor(), owner);
  }

  function testTaxControl() public {
    vm.prank(addr1);
    vm.expectRevert(abi.encodeWithSelector(Governable.GovernableUnauthorizedAccount.selector, addr1));
    token.setBuyTax(700);

    vm.prank(addr1);
    vm.expectRevert(abi.encodeWithSelector(Governable.GovernableUnauthorizedAccount.selector, addr1));
    token.setSellTax(900);

    vm.expectRevert();
    token.setBuyTax(10001);

    vm.expectRevert();
    token.setSellTax(10001);

    token.setBuyTax(900);
    assertEq(token.buyTax(), 900);

    token.setSellTax(3450);
    assertEq(token.sellTax(), 3450);
  }

  function testSetTreasury() public {
    vm.prank(addr1);
    vm.expectRevert(abi.encodeWithSelector(Governable.GovernableUnauthorizedAccount.selector, addr1));
    token.setTreasury(addr1);

    vm.expectRevert("Treasury cannot be zero address");
    token.setTreasury(address(0));

    token.setTreasury(addr1);
  }

  function testMaxSupply() public {
    uint256 maxIssuance = token.MAX_SUPPLY() - VESTING_AMOUNT;
    uint256 maxSupply = token.MAX_SUPPLY();
    token.issue(maxIssuance);
    vm.expectRevert(abi.encodeWithSelector(IAXE.ERC20ExceededCap.selector, maxSupply + 1, maxSupply));
    token.issue(1);
  }

  function testIssuance() public {
    vm.prank(addr1);
    vm.expectRevert(abi.encodeWithSelector(Governable.GovernableUnauthorizedAccount.selector, addr1));
    token.issue(1000);

    uint256 issueAmount = 1000;
    token.issue(issueAmount);
    assertEq(token.balanceOf(owner), 1000, "Issue amount should be 1000");

    issueAmount = 5005;
    token.issue(issueAmount);
    assertEq(token.balanceOf(owner), 6005, "Issue amount should be 6005");
  }

  function testVesting() public {
    assertEq(token.balanceOf(address(vestingWallet)), VESTING_AMOUNT);

    uint256 releasable = vestingWallet.releasable(address(token));
    assertEq(releasable, 0);

    vm.warp(block.timestamp + 72000);
    vestingWallet.release(address(token));
    assertGt(token.balanceOf(owner), 0);

    vm.warp(block.timestamp + VESTING_DURATION);
    vestingWallet.release(address(token));
    assertEq(token.balanceOf(owner), VESTING_AMOUNT);
  }
}
