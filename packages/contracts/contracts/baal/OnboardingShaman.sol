// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IBaal } from "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";

contract OnboardingShaman {
    IBaal public dao;


    constructor(address _dao) {
        dao = IBaal(_dao);
    }

    function deposit(uint256 _amount) external {

    }

}