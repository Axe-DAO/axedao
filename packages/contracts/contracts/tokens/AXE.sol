// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import { Governable } from "../utils/Governable.sol";
import { AXERC20 } from "./XERC20/AXERC20.sol";
import { IAXE } from "./IAXE.sol";

/**
 * @title Axé Token
 * @dev A XERC20 token that can collect a tax on trade activity in a configurable Uniswap v2 pool.
 * The token is controlled by a governor who can change fees and withdraw accumulated assets into
 * a treasury.
 * This token symbolizes positive energy in reference to the term and concept of "Axé" in Capoeira and Candomblé.
 */
contract AXE is IAXE, AXERC20 {
  using SafeERC20 for IERC20;

  /// @dev MAX SUPPLY honors Mestre Pastinha and Mestre Bimba by encoding their birthdays.
  /// M. Pastinha was born 10 years before M. Bimba, so going backwards in order of their birthdays gets us
  /// close to a target of 10 billion tokens: 18[99]/[11]/[23], 18[89]/0[4]/0[5]
  uint256 public constant MAX_SUPPLY = 9_911_238_945 * (10 ** 18);
  string internal constant _NAME = unicode"Axé";
  string internal constant _SYMBOL = unicode"AXÉ";
  /// @dev the governor treasury by default is set to the governor address which is the typical setup for a
  /// Gnosis Safe-based multi-sig. However, the treasury is treated as a separate address in case it becomes
  /// necessary to change in the future.
  address internal governorTreasury;
  uint256 public buyTax = 300;
  uint256 public sellTax = 500;
  address public uniswapV2Router;
  address public liquidationPair;
  address public liquidationToken;
  mapping(address => bool) private taxablePairs;
  mapping(address => bool) private excluded;

  /// @dev Value between 0-10000: E.g. 50 = 0.5%, 9990 = 99.9%
  modifier onlyBasisPoints(uint256 value) {
    require(value <= 10000, "Value must be in basis points");
    _;
  }

  /**
   * @dev Constructor - Mints the vesting amount for the founder into a VestingWallet and gives control to the governor.
   * @param _governor - the DAO's multisig
   */
  constructor(address _governor) Governable(_governor) AXERC20(_NAME, _SYMBOL) {
    require(_governor != address(0), "AXE requires a governor");
    governorTreasury = _governor; // The default
    //exclude treasury and this contract from fees
    excluded[governorTreasury] = true;
    excluded[address(this)] = true;
  }

  /**
   * @notice Sets a new treasury address
   * @param _treasury - the new treasury address
   */
  function setTreasury(address _treasury) external onlyGovernor {
    require(_treasury != address(0), "Treasury cannot be zero address");
    governorTreasury = _treasury;
    emit TreasuryChanged(_treasury);
  }

  /**
   * Sets a new buy tax in basis points.
   * @param _basisPoints must be between 0 and 10000d
   */
  function setBuyTax(uint256 _basisPoints) external onlyGovernor onlyBasisPoints(_basisPoints) {
    buyTax = _basisPoints;
    emit BuyTaxChanged(_basisPoints);
  }

  /**
   * Sets a new sell tax in basis points.
   * @param _basisPoints must be between 0 and 10000
   */
  function setSellTax(uint256 _basisPoints) external onlyGovernor onlyBasisPoints(_basisPoints) {
    sellTax = _basisPoints;
    emit SellTaxChanged(_basisPoints);
  }

  /**
   * @dev Adds the given pair to the list of taxable pools
   * @param _pair - a UniswapV2Pair
   */
  function addTaxablePair(address _pair) external onlyGovernor {
    require(_pair != address(0), "Cannot add zero address");
    require(
      IUniswapV2Pair(_pair).token0() == address(this) || IUniswapV2Pair(_pair).token1() == address(this),
      "Pair must contain this token"
    );
    taxablePairs[_pair] = true;
    emit TaxablePairAdded(_pair);
  }

  /**
   * @dev Removes the given pair from the list of taxable pairs
   * @param _pair - a UniswapV2Pair
   */
  function removeTaxablePair(address _pair) external onlyGovernor {
    taxablePairs[_pair] = false;
    emit TaxablePairRemoved(_pair);
  }

  /**
   * Sets a new router and liquidity token. If the router does not have an existing pair of AXE <-> liquidityToken,
   * a pair will be automatically created.
   * @param _router the UniswapV2Router
   * @param _swapToken an IERC20 token used to liquidate AXE
   */
  function setLiquidationRouterAndToken(address _router, address _swapToken) public onlyGovernor returns (address) {
    require(_router != address(0), "Router cannot be zero address");
    require(_swapToken != address(0), "Liquidity token cannot be zero address");
    //  IUniswapV2Router02(uniswapV2Router).
    // set router and token for swapping
    uniswapV2Router = _router;
    liquidationToken = _swapToken;
    // Check for existing pair or create a new one
    address existingPair = IUniswapV2Factory(IUniswapV2Router02(uniswapV2Router).factory()).getPair(
      address(this),
      _swapToken
    );
    if (address(0) == existingPair) {
      // Create a uniswap pair for the new token
      liquidationPair = IUniswapV2Factory(IUniswapV2Router02(uniswapV2Router).factory()).createPair(
        address(this),
        _swapToken
      );
    } else {
      liquidationPair = existingPair;
    }
    // Add pair to be taxed
    if (!taxablePairs[liquidationPair]) {
      taxablePairs[liquidationPair] = true;
      emit TaxablePairAdded(liquidationPair);
    }

    emit LiquidationSettingsChanged(_router, _swapToken, liquidationPair);
    return liquidationPair;
  }

  /**
   * @dev Attempts to swap the given amount of AXE for the liquidity token and deposits the output into
   * the #governorTreasury (since UniswapV2Router02 does not allow the recipient to be part of the pair).
   * @param _amount how much AXE to swap
   * @param _slippage how much slippage to set for the swap to the liquidityToken
   */
  function liquidate(uint256 _amount, uint256 _slippage) external onlyGovernor onlyBasisPoints(_slippage) {
    require(_canLiquidate(), "Invoking this function requires a router, swap token, and liquidity pair to be set up!");
    require(
      _amount > 0 && _amount <= balanceOf(address(this)),
      "Liquidation amount must be between 0 and max balance."
    );
    // Approve router spending AXÉ
    _approve(address(this), uniswapV2Router, _amount);
    uint deadline = block.timestamp + (10 * 60); // 10 min
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = liquidationToken;

    // calculate slippage and adjust amountOut accordingly
    uint256 amountOut = 0;
    IUniswapV2Router02 router = IUniswapV2Router02(uniswapV2Router);
    (uint112 axeReserve, uint112 tokenReserve) = _getLiquidationReserves();
    amountOut = router.getAmountOut(_amount, axeReserve, tokenReserve);
    amountOut = amountOut - _applyBasisPoints(_slippage, amountOut);

    uint[] memory amounts = router.swapExactTokensForTokens(_amount, amountOut, path, governorTreasury, deadline);
    emit AxeLiquidated(path[1], _amount, amounts[0]);
  }

  /**
   * Withdraws the specified amount of native currency to the treasury. If the amount exceeds the balance,
   * the available balance is transfered.
   * This function is only needed in case anyone sent native tokens to this contract (by accident).
   * @param _amount The amount to withdraw
   */
  function withdraw(uint256 _amount) external onlyGovernor {
    uint256 balance = address(this).balance;
    if (balance > 0 && _amount > 0) {
      uint256 transfer = _amount < balance ? _amount : balance;
      payable(governorTreasury).transfer(transfer);
      emit NativeWithdrawn(transfer);
    }
  }

  /**
   * Withdraws the specified amount of the given token to the treasury. If the amount exceeds the balance,
   * the available balance is transfered.
   * This function is used to withdraw accumulated AXÉ fees, but can also be used to rescue any ERC20 token
   * accidentally sent to this contract.
   * @param _token the token to withdraw from
   * @param _amount the amount to withdraw
   */
  function withdrawToken(address _token, uint256 _amount) external onlyGovernor {
    IERC20 token = IERC20(_token);
    uint256 balance = token.balanceOf(address(this));
    if (balance > 0 && _amount > 0) {
      uint256 transfer = _amount < balance ? _amount : balance;
      token.transfer(governorTreasury, transfer);
      emit TokenWithdrawn(_token, transfer);
    }
  }

  /**
   * @dev Overrides ERC20#_update(address,address,uint256) to impose buy/sell fees.
   * Also enforces the MAX_SUPPLY when minting.
   */
  function _update(address _from, address _to, uint256 _value) internal override {
    // Don't intervene on minting/burning
    if (_from == address(0) || _to == address(0)) {
      super._update(_from, _to, _value);
      // Checking ERC20ExceededCap
      uint256 supply = totalSupply();
      if (supply > MAX_SUPPLY) {
        revert ERC20ExceededCap(supply, MAX_SUPPLY);
      }
      return;
    }
    uint256 fee;
    uint256 adjustedValue = _value;
    if (!excluded[_from] && !excluded[_to]) {
      // BUY
      if (taxablePairs[_from] && buyTax > 0) {
        fee = _applyBasisPoints(buyTax, _value);
        super._update(_from, address(this), fee);
        adjustedValue -= fee;
        emit BuyTaxApplied(_value, buyTax, fee, _to);
      }
      // SELL
      else if (taxablePairs[_to] && sellTax > 0) {
        fee = _applyBasisPoints(sellTax, _value);
        super._update(_from, address(this), fee);
        adjustedValue -= fee;
        emit SellTaxApplied(_value, buyTax, fee, _from);
      }
    }
    super._update(_from, _to, adjustedValue);
  }

  /**
   * Applies the speciied percentage in basis points to the given amount and returns the result.
   * @param _basisPoints a fee/tax in basis points
   * @param _amount the amount on which to apply the percentage
   */
  function _applyBasisPoints(uint256 _basisPoints, uint256 _amount) internal pure returns (uint256 result) {
    result = (_amount * _basisPoints) / (10 ** 4);
  }

  /// @dev Returns true if a router, liquidation pair, and liquidation token are set
  function _canLiquidate() internal view returns (bool success) {
    return uniswapV2Router != address(0) && liquidationPair != address(0) && liquidationToken != address(0);
  }

  /// @dev Sorts the liquidationPair reserves to return AXÉ reserves first.
  function _getLiquidationReserves() internal view returns (uint112, uint112) {
    (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(liquidationPair).getReserves();
    return IUniswapV2Pair(liquidationPair).token0() == address(this) ? (reserve0, reserve1) : (reserve1, reserve0);
  }

  //to receive native tokens
  receive() external payable {}
}
