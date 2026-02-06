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


import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    // We need to pass the token address to the constructor
    // Create a deposit function that mints tokens to the user equivalent to the amount of ETH they deposited
    // Create a redeem function that burns the user tokens and send the user the ETH equivalent
    // Create a way to add reward to the vault

    /**
     * ERRORS
     */
    error Vault__RedeemFailed();

    /**
     * STATE VARIABLES
     */
    IRebaseToken private immutable i_rebaseToken;

    /**
     * EVENTS
     */
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseToken ) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Allows users to deposit and mint RebaseToken in return
     */
    function deposit() external payable {
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);

    }

    /**
     * @notice Allows the user to redeem their Rebase Token to ETH
     * @param _amount The amount of Rebase Token to redeem 
     */
    function redeem(uint256 _amount) external {
        // to mitigate against dust (User wanting to withdraw their entire staked amount)
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // 1. Burn the token from the user
        i_rebaseToken.burn(msg.sender, _amount);

        // we need to send the user ETH
        (bool success,) = payable(msg.sender).call{value: _amount}("");

        if (!success) {
        revert Vault__RedeemFailed();
        }

        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice Gets the address of the Rebase Token
     * @return Returns the address of the Rebase Token
     */
    function getRebaseTokenAddress() external view returns(address) {
        return address(i_rebaseToken);
    }
}