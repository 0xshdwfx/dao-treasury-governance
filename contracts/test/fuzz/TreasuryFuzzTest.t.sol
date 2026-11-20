// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../src/Treasury.sol";

contract TreasuryFuzzTest is Test {
    Treasury public treasury;

    address public timelockOwner = makeAddr("timelockOwner");
    address public recipient = makeAddr("recipient");

    function setUp() public {
        treasury = new Treasury(timelockOwner);
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
}
