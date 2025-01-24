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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
/**
 * @title RebaseToken
 * @author Onowu Chris
 * @notice This as a cross-chain that incentivize users to deposit unto a vault and gain interest in rewards
 * @notice The interest in the smart contract can only decrease
 * @notice Each user will have it's own interest rate that is the global interest rate at the time of deposit
 */

contract RebaseToken is ERC20, Ownable, AccessControl {
    /**
     * ERRORS
     */
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    /**
     * STATE VARIABLES
     */
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;

    /**
     * EVENTS
     */
    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantBurnAndMintRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Sets the interest rate in the contract
     * @param _newInterestRate The new interest rate to set
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;

        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Gets the principle balance of the user. This is the numbers of Tokens that has been minted
     *          to the user, not including any interest that has been accrued since the last time the user
     *          interacted with the protocol
     * @param _user The user to get the principle balance
     * @return The principle balance of the user
     */
    function principleBalance(address _user) public view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint the token to
     * @param _amount The Amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        // to mitigate against dust (User wanting to withdraw their entire staked amount)
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Calculate the user balance including the interest that has accumulated since the last update
     * (principle balance) + some interest that has accrued
     * @param _user The user balance that needs to be calculated
     * @return The balance of the user and the interest since that last time of update
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user (the numbers of tokens that that have actually been minted to the user)
        // multiple the principle balance by the interest that has accumulated since the time balance was last updated
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice Transfer Tokens from one user to another
     * @param _recipient The recipient to receive the token transfer
     * @param _amount The amount of Token to transfer
     * @return True is the transfer was successful
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        // check for accrued interest for both sender and recipient
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);

        if (_amount == type(uint256).max) {
            _amount == balanceOf(msg.sender);
        }

        // set recipient interest rate
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer Token from one user to another user
     * @param _sender The sender of the Token
     * @param _recipient The recipient of the Token
     * @param _amount The amount of Token to send
     * @return True if transaction is successful
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }

        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }

        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice Calculate the interest that has accumulated since the last update
     * @param _user The user's interest that needs to be calculated
     * @param linerInterest The users interest
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linerInterest)
    {
        // This is going to be a linear growth with time
        // 1. Calculate the time since the last update
        // 2. Calculate the amount of linear growth
        // (principle amount) + (principle amount * interest rate * time elapsed)
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linerInterest = (1 * PRECISION_FACTOR) + (s_userInterestRate[_user] * timeElapsed);
    }

    /**
     * @notice Mint the accrued interest to the user since the last time they interacted with the protocol (e.g burn, transfer, mint)
     * @param _user The user the accrued to be minted to
     */
    function _mintAccruedInterest(address _user) internal {
        // 1. Find the current balance of Rebase Token that has been minted to the user -> Principle
        uint256 previousPrincipleBalance = super.balanceOf(_user);

        // 2. Calculate their current balance including any interest
        uint256 currentBalance = balanceOf(_user);

        // 3. Calculate the numbers of tokens that is needed to be minted to the use -> (2) - (1) -> Interest
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;

        // 4. Set user last updated timestamp
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;

        // 5. Call _mint to mint the token to the user
        _mint(_user, balanceIncrease);
    }

    /**
     * @notice Gets the interest rate that is currently set for the contract, any future depositor will
     *          inherit this interest rate
     * @return The interest rate for the contract
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Gets the interest rate for the user
     * @param _user The user to get the interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
