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
    uint256 private constant PRECISION_FACTOR = 1E18;
    uint256 private s_interestRate = 5e10;
    mapping (address => uint) private s_userInterestRate;
    mapping (address => uint) private s_userLastUpdatedTimeStamp;

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

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint the token to
     * @param _amount The Amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterestRate(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Calculate the user balance including the interest that has accumulated since the last update
     * (principle balance) + some interest that has accrued
     * @param _user The user balance that needs to be calculated
     * @return The balance of the user and the interest since that last time of update
     */
    function balanceOf(address _user) public view override returns(uint256) {
        // get the current principle balance of the user (the numbers of tokens that that have actually been minted to the user)
        // multiple the principle balance by the interest that has accumulated since the time balance was last updated 
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice Calculate the interest that has accumulated since the last update 
     * @param _user The user's interest that needs to be calculated
     * @param linerInterest The users interest
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns(uint256 linerInterest) {
        // This is going to be a linear growth with time
        // 1. Calculate the time since the last update
        // 2. Calculate the amount of linear growth
        // (principle amount) + (principle amount * interest rate * time elapsed)
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linerInterest = (1 * PRECISION_FACTOR) + (s_userInterestRate[_user] * timeElapsed);
    }

    function _mintAccruedInterestRate(address _user) internal returns(uint256) {
        // 1. Find the current balance of Rebase Token that has been minted to the user -> Principle
        // 2. Calculate their current balance including any interest
        // 3. Calculate the numbers of tokens that is needed to be minted to the use -> (2) - (1) -> Interest
        // 4. Call _mint to mint the token to the user
        // 5. Set user last updated timestamp
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
    }

    /**
     * @notice Gets the interest rate for the user
     * @param _user The user to get the interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(address _user) external view returns(uint256) {
        return s_userInterestRate[_user];
    }

}