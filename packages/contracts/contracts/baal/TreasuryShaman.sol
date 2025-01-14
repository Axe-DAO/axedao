// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IBaal } from "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { ITreasuryShaman } from "./ITreasuryShaman.sol";

/**
 * @title TreasuryShaman
 * @notice Manages deposits to the (rage-quittable) DAO treasury and mints loot tokens in return.
 * The shaman accepts deposits in a specific ERC20 token and mints loot tokens at a configurable rate.
 */
contract TreasuryShaman is ITreasuryShaman, Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  IBaal public immutable baal;
  IERC20 public depositToken;
  address public immutable depositReceiver;
  uint256 public conversionRate; // represented with 18 decimals

  constructor(address _baal, address _depositToken, address _depositReceiver, address _owner) Ownable(_owner) {
    require(_baal != address(0), "Baal cannot be zero address");
    require(_depositToken != address(0), "Deposit token cannot be zero address");
    require(_depositReceiver != address(0), "Receiver cannot be zero address");

    baal = IBaal(_baal);
    depositToken = IERC20(_depositToken);
    depositReceiver = _depositReceiver;
    conversionRate = 1e18; // Initial 1:1 conversion rate
  }

  /**
   * @notice Allows users to deposit ERC20 tokens and receive loot in return.
   * @param _amount The amount of tokens to deposit
   */
  function deposit(uint256 _amount) external nonReentrant {
    if (_amount == 0) revert InsufficientDeposit();
    address sender = _msgSender();

    // Calculate loot to mint (considering both token decimals)
    uint256 depositDecimals = IERC20Metadata(address(depositToken)).decimals();
    uint256 lootDecimals = IERC20Metadata(baal.lootToken()).decimals();
    uint256 lootAmount = (_amount * conversionRate * (10 ** lootDecimals)) / (10 ** (depositDecimals + 18));

    // Mint loot tokens
    address[] memory recipients = new address[](1);
    recipients[0] = sender;
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = lootAmount;
    baal.mintLoot(recipients, amounts);

    // Transfer tokens to deposit receiver
    depositToken.safeTransferFrom(sender, depositReceiver, _amount);
    emit TreasuryDepositReceived(sender, _amount, lootAmount);
  }

  /**
   * @notice Allows owner to update the conversion rate
   * @param _newRate The new conversion rate (with 18 decimals)
   */
  function setConversionRate(uint256 _newRate) external onlyOwner {
    if (_newRate == 0) revert InvalidConversionRate();

    uint256 oldRate = conversionRate;
    conversionRate = _newRate;

    emit ConversionRateUpdated(oldRate, _newRate);
  }

  /**
   * @notice Allows owner to update the deposit token
   * @param _newToken The new token address
   */
  function setDepositToken(address _newToken) external onlyOwner {
    if (_newToken == address(0)) revert InvalidDepositToken();

    address oldToken = address(depositToken);
    depositToken = IERC20(_newToken);

    emit DepositTokenUpdated(oldToken, _newToken);
  }
}
