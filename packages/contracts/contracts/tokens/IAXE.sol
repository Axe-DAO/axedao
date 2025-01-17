// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IAXE {
  /**
   * @dev Total supply cap has been exceeded.
   */
  error ERC20ExceededCap(uint256 increasedSupply, uint256 cap);
  /**
   * @notice Emits when the treasury address is changed
   * @param value - the new treasury address
   */
  event TreasuryChanged(address value);
  /**
   * @notice Emits when the sell tax is changed
   * @param value - the new sell tax
   */
  event SellTaxChanged(uint256 value);
  /**
   * @notice Emits when the sell tax is changed
   * @param value - the new sell tax
   */
  event BuyTaxChanged(uint256 value);
  /**
   * @notice Emits when a AXÉ<->token pair was set to be taxable
   * @param pair - the IUniswapV2Pair address being taxed
   */
  event TaxablePairAdded(address pair);
  /**
   * @notice Emits when a AXÉ<->token pair was set to be not taxable
   * @param pair - the IUniswapV2Pair address no longer being taxed
   */
  event TaxablePairRemoved(address pair);
  /**
   * @notice Emits when Axé was liquidated / swapped for the liquidation token
   * @param swapToken - the token against which Axé was swapped
   * @param axeAmount - the amount of Axé liquidated
   * @param outputAmount - the output amount of the liquidity token
   */
  event AxeLiquidated(address swapToken, uint256 axeAmount, uint256 outputAmount);
  /**
   * @notice Emits when the liquidation settings have changed
   * @param router - the addresses of the IUniswapV2Router02
   * @param swapToken - the token used for swapping Axé upon liquidation
   * @param pair - AXÉ<->token pair used for liquidation
   */
  event LiquidationSettingsChanged(address router, address swapToken, address pair);
  /**
   * @notice Emits when a buy tax was applied
   * @param tradeAmount - the amount of Axé being taxed
   * @param basisPoints - the fee percentage in BPS applied
   * @param spender - the account paying the tax
   */
  event BuyTaxApplied(uint256 tradeAmount, uint256 basisPoints, uint256 feeAmount, address indexed spender);
  /**
   * @notice Emits when a sell tax was applied
   * @param tradeAmount - the amount of Axé being taxed
   * @param basisPoints - the fee percentage in BPS applied
   * @param spender - the account paying the tax
   */
  event SellTaxApplied(uint256 tradeAmount, uint256 basisPoints, uint256 feeAmount, address indexed spender);
  /**
   * @notice Emits when native currency is withdrawn from the Axé contract
   * @param amount - the amount withdrawn
   */
  event NativeWithdrawn(uint256 amount);
  /**
   * @notice Emits when an ERC20 balance is withdrawn from the Axé contract
   * @param amount - the amount withdrawn
   */
  event TokenWithdrawn(address indexed token, uint256 amount);

  /**
   * @notice Sets a new treasury address
   * @param treasury - the new treasury address
   */
  function setTreasury(address treasury) external;

  /**
   * @notice Sets a new buy tax in basis points.
   * @param basisPoints - the new basis points value
   */
  function setBuyTax(uint256 basisPoints) external;

  /**
   * @notice Sets a new sell tax in basis points.
   * @param basisPoints - the new basis points value
   */
  function setSellTax(uint256 basisPoints) external;

  /**
   * @notice Adds the given pair to the list of taxable pairs
   * @param pair - the UniswapV2Pair to be taxed
   */
  function addTaxablePair(address pair) external;

  /**
   * @notice Removes the given pair from the list of taxable pairs
   * @param pair - the UniswapV2Pair to not be taxed
   */
  function removeTaxablePair(address pair) external;

  /**
   * @notice Sets the liquidation settings to use the specified router and liquidity token.
   * @param router the UniswapV2Router
   * @param swapToken an IERC20 token used to liquidate Axé
   */
  function setLiquidationRouterAndToken(address router, address swapToken) external returns (address);

  /**
   * @notice Attempts to swap the given amount of Axé for the highest possible amount of
   * the liquidity token.
   * @param amount how much Axé to liquidate
   * @param slippage how much slippage to allow for the swap
   */
  function liquidate(uint256 amount, uint256 slippage) external;

  /**
   * @notice Withdraws the specified amount of native currency to the treasury, if available.
   * This function is included in case anyone sent native tokens by accident to this contract.
   * @param amount - the amount of native tokens to withdraw
   */
  function withdraw(uint256 amount) external;

  /**
   * @notice Withdraws the specified amount of the given token to the treasury, if available.
   * @param token the token to withdraw from
   * @param amount the amount to withdraw
   */
  function withdrawToken(address token, uint256 amount) external;
}
