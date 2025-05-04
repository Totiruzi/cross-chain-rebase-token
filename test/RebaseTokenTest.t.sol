// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
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
        (bool success,) = payable(address(vault)).call{value:1e18}("");
        vm.stopPrank();
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
        // 4. warp the time again by the same amount and check our rebase balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(USER);
        assertGt(endBalance, middleBalance);

        // the assertion of linear interest is constant (that is the initial amount of growth after an hour and the growth after a second hour are constant) like this
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();
    }
}
