// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title ITreasuryShaman
 * @notice Interface for the TreasuryShaman contract
 */
interface ITreasuryShaman {
  event TreasuryDepositReceived(address indexed depositor, uint256 amount, uint256 lootMinted);
  event ConversionRateUpdated(uint256 oldRate, uint256 newRate);
  event DepositTokenUpdated(address indexed oldToken, address indexed newToken);

  error InvalidConversionRate();
  error InsufficientDeposit();
  error InvalidDepositReceiver();
  error InvalidDepositToken();

  function deposit(uint256 amount) external;

  function setConversionRate(uint256 newRate) external;

  function setDepositToken(address newToken) external;
}
