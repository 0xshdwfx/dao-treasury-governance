// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../src/Treasury.sol";
import {ShadowToken} from "../../src/ShadowToken.sol";

contract TreasuryFuzzTest is Test {
    Treasury public treasury;
    ShadowToken public shadowToken;

    address public timelockOwner = makeAddr("timelockOwner");
    address public recipient = makeAddr("recipient");

    function setUp() public {
        treasury = new Treasury(timelockOwner);
        shadowToken = new ShadowToken();
    }

    function testFuzz_WithdrawTreasuryETH_TransfersRequestedAmount_WhenAmountIsWithinBalance(
        uint256 treasuryBalance,
        uint256 withdrawalAmount
    ) public {
        treasuryBalance = bound(treasuryBalance, 1 wei, type(uint128).max);
        withdrawalAmount = bound(withdrawalAmount, 1 wei, treasuryBalance);

        deal(address(treasury), treasuryBalance);

        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(timelockOwner);
        treasury.transferEth(payable(recipient), withdrawalAmount);

        assertEq(
            address(treasury).balance,
            treasuryBalance - withdrawalAmount,
            "Treasury balance should decrease by withdrawal amount"
        );

        assertEq(
            recipient.balance,
            recipientBalanceBefore + withdrawalAmount,
            "Recipient balace should increase by withdrawal amount"
        );
    }

    function testFuzz_WithdrawTreasuryETH_Reverts_WhenAmountExceedsTreasuryBalance(
        uint256 treasuryBalance,
        uint256 withdrawalAmount
    ) public {
        treasuryBalance = bound(treasuryBalance, 1 wei, type(uint128).max);
        withdrawalAmount = bound(withdrawalAmount, treasuryBalance + 1, type(uint256).max);

        deal(address(treasury), treasuryBalance);

        uint256 treasuryBalanceBefore = address(treasury).balance;
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__TransferAmountExceedsTreasuryBalance.selector);
        treasury.transferEth(payable(recipient), withdrawalAmount);

        uint256 treasuryBalanceAfter = address(treasury).balance;
        uint256 recipientBalanceAfter = recipient.balance;

        assertEq(treasuryBalanceAfter, treasuryBalanceBefore, "Treasury balance should remain the same");
        assertEq(recipientBalanceAfter, recipientBalanceBefore, "Recipient balance should remain the same");
    }

    function testFuzz_WithdrawTreasuryERC20_TransfersRequestedAmount_WhenAmountIsWithinBalance(
        uint256 treasuryTokenBalance,
        uint256 withdrawalAmount
    ) public {
        treasuryTokenBalance = bound(treasuryTokenBalance, 1, shadowToken.totalSupply());
        withdrawalAmount = bound(withdrawalAmount, 1, treasuryTokenBalance);

        bool success = shadowToken.transfer(address(treasury), treasuryTokenBalance);
        assertTrue(success, "SHDW token transfer should succeed");

        uint256 treasuryTokenBalanceBefore = shadowToken.balanceOf(address(treasury));
        uint256 recipientTokenBalanceBefore = shadowToken.balanceOf(recipient);

        vm.prank(timelockOwner);
        treasury.transferERC20(address(shadowToken), recipient, withdrawalAmount);

        uint256 treasuryTokenBalanceAfter = shadowToken.balanceOf(address(treasury));
        uint256 recipientTokenBalanceAfter = shadowToken.balanceOf(recipient);

        assertEq(
            treasuryTokenBalanceAfter,
            treasuryTokenBalanceBefore - withdrawalAmount,
            "Treasury token balance should decrease by withdrawal amount"
        );

        assertEq(
            recipientTokenBalanceAfter,
            recipientTokenBalanceBefore + withdrawalAmount,
            "Recipient token balance should increase by withdrawal amount"
        );
    }
}
