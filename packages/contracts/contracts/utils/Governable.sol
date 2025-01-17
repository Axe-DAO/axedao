// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { Context } from "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Adaptation of the OpenZeppelin Contract "access/Ownable.sol" with the
 * #renounceOwnership() function removed and the state variables / functions
 * renamed from "Ownable" and "owner" to "Governable" and "governor"
 *
 *  Contract module which provides a basic access control mechanism, where
 * there is an account (an governor) that can be granted exclusive access to
 * specific functions.
 *
 * The initial governor is set to the address provided by the deployer. This can
 * later be changed with {transferGovernorship}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyGovernor`, which can be applied to your functions to restrict their use to
 * the governor.
 */
abstract contract Governable is Context {
  address private _governor;

  /**
   * @dev The caller account is not authorized to perform an operation.
   */
  error GovernableUnauthorizedAccount(address account);

  /**
   * @dev The governor is not a valid governor account. (eg. `address(0)`)
   */
  error GovernableInvalidGovernor(address governor);

  event GovernorshipTransferred(address indexed previousGovernor, address indexed newGovernor);

  /**
   * @dev Initializes the contract setting the address provided by the deployer as the initial governor.
   * @param _initialGovernor The address of the initial governor
   */
  constructor(address _initialGovernor) {
    if (_initialGovernor == address(0)) {
      revert GovernableInvalidGovernor(address(0));
    }
    _transferGovernorship(_initialGovernor);
  }

  /**
   * @dev Throws if called by any account other than the governor.
   */
  modifier onlyGovernor() {
    _checkGovernor();
    _;
  }

  /**
   * @dev Returns the address of the current governor.
   */
  function governor() public view virtual returns (address) {
    return _governor;
  }

  /**
   * @dev Throws if the sender is not the governor.
   */
  function _checkGovernor() internal view virtual {
    if (governor() != _msgSender()) {
      revert GovernableUnauthorizedAccount(_msgSender());
    }
  }

  /**
   * @dev Transfers governorship of the contract to a new account (`newGovernor`).
   * Can only be called by the current governor.
   * @param _newGovernor The address of the new governor
   */
  function transferGovernorship(address _newGovernor) public virtual onlyGovernor {
    if (_newGovernor == address(0)) {
      revert GovernableInvalidGovernor(address(0));
    }
    _transferGovernorship(_newGovernor);
  }

  /**
   * @dev Transfers governorship of the contract to the specified account.
   * Internal function without access restriction.
   * @param _newGovernor The address of the new governor
   */
  function _transferGovernorship(address _newGovernor) internal virtual {
    address oldGovernor = _governor;
    _governor = _newGovernor;
    emit GovernorshipTransferred(oldGovernor, _newGovernor);
  }
}
