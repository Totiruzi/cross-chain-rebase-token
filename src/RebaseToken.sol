// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
/**
 * @title RebaseToken
 * @author Onowu Chris
 * @notice This as a cross-chain that incentivize users to deposit unto a vault and gain interest in rewards
 * @notice The interest in the smart contract can only decrease
 * @notice Each user will have it's own interest rate that is the global interest rate at the time of deposit
 */
contract RebaseToken is ERC20{
    /**
     * ERRORS
     */
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    /**
     * STATE VARIABLES
     */
    uint256 private s_interestRate = 5e10;

    /**
     * EVENTS
     */
    event  InterestRateSet(uint256 newInterestRate);

    constructor() ERC20('Rebase Token', 'RBT') {}

    /**
     * @notice Sets the interest rate in the contract
     * @param _newInterestRate The new interest rate to set
     * @dev The interest rate can only decrease 
     */
    function setInterestRate(uint256 _newInterestRate)  external {
        if(_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;

        emit InterestRateSet(_newInterestRate);
    }
}