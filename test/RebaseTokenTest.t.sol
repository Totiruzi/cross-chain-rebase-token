// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";


contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault; 
    address USER = makeAddr("user");
    address OWNER = makeAddr("owner");
    function setUp() public{
        vm.startPrank(OWNER);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantBurnAndMintRole(address(vault));
        vm.stopPrank();
    }

    function addRewardToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value:rewardAmount}("");
    }

    function testDepositLinear(uint256 amount) public {
        // vm.assume(amount > 1e5); vm.assume is discard the test is the amount is less than 1e5 so we use bound to keep the range of amount between 1e5 to have has many fuzz test as possible 
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. Deposit
        vm.startPrank(USER);
        vm.deal(USER, amount);
        vault.deposit{value: amount}();
        // 2. Check our rebase balance
        uint256 startBalance = rebaseToken.balanceOf(USER);
        console2.log(" ~ testDepositLinear ~ startBalance:", startBalance);
        assertEq(startBalance, amount);
        // 3. Warp the time and check our rebase balance
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(USER);
        assertGt(middleBalance, startBalance);
        // 4. warp the time again by the same amount of time and check our rebase balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(USER);
        assertGt(endBalance, middleBalance);

        // the assertion of linear interest is constant (that is the initial amount of growth after an hour and the growth after a second hour are constant) like this
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // deposit into the vault
        vm.startPrank(USER);
        vm.deal(USER, amount);
        vault.deposit{value: amount}();
        uint256 userBalance = rebaseToken.balanceOf(USER);
        assertEq(userBalance, amount);

        // redeem token
        vault.redeem(type(uint256).max);
        uint256 userBalanceAfterRedeem = rebaseToken.balanceOf(USER);
        uint256 totalUserBalance = address(USER).balance;

        assertEq(userBalanceAfterRedeem, 0);
        assertEq(totalUserBalance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        time = bound(time, 1000, type(uint96).max);
        // deposit
        vm.deal(USER, depositAmount);
        vm.prank(USER);
        vault.deposit{value: depositAmount}();

        // warp the time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(USER);
        vm.deal(OWNER, balanceAfterSomeTime - depositAmount);

        // add reward to vault
        vm.prank(OWNER);
        addRewardToVault(balanceAfterSomeTime - depositAmount);
        // redeem
        vm.prank(USER);
        vault.redeem(type(uint256).max);

        uint256 userEthBalance = address(USER).balance;

        // assertEq(userEthBalance, balance);
        assertGt(userEthBalance, depositAmount);
        assertEq(userEthBalance, balanceAfterSomeTime);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        // 1. deposit to the vault
        vm.deal(USER, amount);
        vm.prank(USER);
        vault.deposit{value: amount}();
        uint256 userBalance = rebaseToken.balanceOf(USER);
        assertEq(userBalance, amount);

        // User to transfer token to
        address user2 = makeAddr("user2");
        uint256 user2Balance =  rebaseToken.balanceOf(user2);
        assertEq(user2Balance, 0);

        // Owner reduces interest rate before sending amount to user2
        vm.prank(OWNER);
        rebaseToken.setInterestRate(4e10);

        // 2. send amount
        vm.prank(USER);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(USER);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);

        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        // check user Interest rate has been inherited (4e10 and not 5e10)
        uint256 userInterestRate = rebaseToken.getUserInterestRate(USER);
        uint256 user2InterestRate = rebaseToken.getUserInterestRate(user2);
        uint256 universalInterestRate = rebaseToken.getInterestRate();
        assertEq(userInterestRate, 5e10);
        assertEq(user2InterestRate, 5e10);
        assertEq(universalInterestRate, 4e10);

    }

    function testCanNotSetInterestRateIfNotOwner(uint256 newInterestRate) public {
        vm.prank(USER);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCanNotCallMintAndBurn() public {
        vm.prank(USER);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mint(USER, 100, rebaseToken.getInterestRate());

        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burn(USER, 100);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(USER, amount);

        vm.prank(USER);
        vault.deposit{value: amount}();

        assertEq(rebaseToken.principleBalance(USER), amount);

        // check that principle amount stays the same after sometime have passed
        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalance(USER), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address (rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max);
        vm.prank(OWNER);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(newInterestRate);

        uint256 currentInterestRate = rebaseToken.getInterestRate();
        assertEq(currentInterestRate, initialInterestRate);
    }
}
