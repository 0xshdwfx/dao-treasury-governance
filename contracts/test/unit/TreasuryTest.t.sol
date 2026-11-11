// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Treasury} from "../../src/Treasury.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RejectingETHRecipient} from "../mocks/RejectingETHRecipient.sol";
import {ShadowToken} from "../../src/ShadowToken.sol";

contract TreasuryTest is Test {
    Treasury public treasury;
    RejectingETHRecipient public rejectingETHRecipient;
    ShadowToken public shadowToken;

    address public timelockOwner = makeAddr("timelockOwner");
    address public user = makeAddr("user");
    address public recipient = makeAddr("recipient");
    address public tokenDeployer = makeAddr("tokenDeployer");

    uint256 public constant ETH_AMOUNT = 1e18;
    uint256 public constant TRANSFER_AMOUNT = 100e18;

    // events
    event EthTransferred(address indexed recipient, uint256 amount);

    function setUp() public {
        treasury = new Treasury(timelockOwner);
        rejectingETHRecipient = new RejectingETHRecipient();

        vm.prank(tokenDeployer);
        shadowToken = new ShadowToken();
    }

    ///////////////////
    /// Deployment ///
    /////////////////

    function test_DeployTreasury_AssignsOwnershipToConfiguredTimelock() public view {
        assertEq(treasury.owner(), timelockOwner, "Treasury owner must equal Timelock address");
    }

    function test_DeployTreasury_Reverts_WhenTimelockAddressIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new Treasury(address(0));
    }

    ///////////////////////////////
    /// Ownership Restrictions ///
    /////////////////////////////

    function test_TransferOwnership_Reverts_WhenCalledByTimelockOwner() public {
        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__OwnershipChangeDisabled.selector);

        treasury.transferOwnership(user);

        assertEq(treasury.owner(), timelockOwner, "Treasury ownership should still equal timelock address");
    }

    function test_RenounceOwnership_Reverts_WhenCalledByTimelockOwner() public {
        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__OwnershipChangeDisabled.selector);

        treasury.renounceOwnership();

        assertEq(treasury.owner(), timelockOwner, "Treasury ownership should still equal timelock address");
    }

    ///////////////////////
    /// Asset Deposits ///
    /////////////////////

    function test_DepositTreasuryETH_IncreasesTreasuryBalance_WhenSentByOrdinaryUser() public {
        deal(user, ETH_AMOUNT);

        vm.prank(user);

        (bool success,) = address(treasury).call{value: ETH_AMOUNT}("");
        assertTrue(success, "ETH transfer to receive() should succeed");

        assertEq(address(treasury).balance, ETH_AMOUNT, "Treasury ETH balance should increase by deposited amount");
    }

    function test_DepositTreasuryERC20_IncreasesTreasuryTokenBalance_WhenSentByTokenHolder() public {
        uint256 tokenDeployerBalanceBefore = shadowToken.balanceOf(tokenDeployer);
        uint256 treasuryBalanceBefore = shadowToken.balanceOf(address(treasury));

        vm.prank(tokenDeployer);

        bool success = shadowToken.transfer(address(treasury), TRANSFER_AMOUNT);
        assertTrue(success, "Token transfer to treasury should succeed");

        uint256 tokenDeployerBalanceAfter = shadowToken.balanceOf(tokenDeployer);
        uint256 treasuryBalanceAfter = shadowToken.balanceOf(address(treasury));

        assertEq(
            tokenDeployerBalanceAfter,
            tokenDeployerBalanceBefore - TRANSFER_AMOUNT,
            "Token deployer balance should decrease by transfer amount"
        );

        assertEq(
            treasuryBalanceAfter,
            treasuryBalanceBefore + TRANSFER_AMOUNT,
            "Treasury token balance should increase by the transfer amount"
        );
    }

    //////////////////////
    /// ETH Transfers ///
    ////////////////////

    function test_WithdrawTreasuryETH_TransfersRequestedAmount_WhenCalledByTimelockOwner() public {
        deal(address(treasury), ETH_AMOUNT);

        uint256 userBalanceBefore = user.balance;

        vm.expectEmit(true, false, false, true, address(treasury));
        emit EthTransferred(user, ETH_AMOUNT);

        vm.prank(timelockOwner);
        treasury.transferEth(payable(user), ETH_AMOUNT);

        assertEq(address(treasury).balance, 0, "Treasury balance should decrease by the transferred amount");
        assertEq(
            user.balance, userBalanceBefore + ETH_AMOUNT, "Recipient balance should increase by transferred amount"
        );
    }

    function test_WithdrawTreasuryETH_Reverts_WhenCalledByOrdinaryUser() public {
        deal(address(treasury), ETH_AMOUNT);
        uint256 treasuryBalanceBefore = address(treasury).balance;
        uint256 userBalanceBefore = user.balance;

        vm.prank(user);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));

        treasury.transferEth(payable(user), ETH_AMOUNT);

        assertEq(address(treasury).balance, treasuryBalanceBefore, "Treasury balance should remain unchanged");

        assertEq(user.balance, userBalanceBefore, "User balance should remain unchanged");
    }

    function test_WithdrawTreasuryETH_Reverts_WhenRecipientIsZeroAddress() public {
        deal(address(treasury), ETH_AMOUNT);
        uint256 treasuryBalanceBefore = address(treasury).balance;

        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__InvalidRecipient.selector);

        treasury.transferEth(payable(address(0)), ETH_AMOUNT);

        assertEq(address(treasury).balance, treasuryBalanceBefore, "Treasury balance should remain unchanged");
    }

    function test_WithdrawTreasuryETH_Reverts_WhenAmountIsZero() public {
        deal(address(treasury), ETH_AMOUNT);
        uint256 treasuryBalanceBefore = address(treasury).balance;
        uint256 userBalanceBefore = user.balance;

        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__InvalidTransferAmount.selector);

        treasury.transferEth(payable(user), 0);

        assertEq(address(treasury).balance, treasuryBalanceBefore, "Treasury balance should remain unchanged");

        assertEq(user.balance, userBalanceBefore, "Recipient balance should remain unchanged");
    }

    function test_WithdrawTreasuryETH_Reverts_WhenAmountExceedsTreasuryBalance() public {
        deal(address(treasury), ETH_AMOUNT);
        uint256 treasuryBalanceBefore = address(treasury).balance;
        uint256 userBalanceBefore = user.balance;

        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__TransferAmountExceedsTreasuryBalance.selector);

        treasury.transferEth(payable(user), ETH_AMOUNT + 1);

        assertEq(address(treasury).balance, treasuryBalanceBefore, "Treasury balance should remain unchanged");

        assertEq(user.balance, userBalanceBefore, "Recipient balance should remain unchanged");
    }

    function test_WithdrawTreasuryETH_Reverts_WhenRecipientRejectsETH() public {
        deal(address(treasury), ETH_AMOUNT);
        uint256 treasuryBalanceBefore = address(treasury).balance;
        uint256 rejectingETHRecipientBalanceBefore = address(rejectingETHRecipient).balance;

        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__EthTransferFailed.selector);

        treasury.transferEth(payable(address(rejectingETHRecipient)), ETH_AMOUNT);

        assertEq(address(treasury).balance, treasuryBalanceBefore, "Treasury balance should remain unchanged");

        assertEq(
            address(rejectingETHRecipient).balance,
            rejectingETHRecipientBalanceBefore,
            "Recipient balance should remain unchanged"
        );
    }

    function test_WithdrawTreasuryETH_PreservesRemainingBalance_WhenWithdrawingPartOfTreasuryFunds() public {
        deal(address(treasury), ETH_AMOUNT);
        uint256 treasuryBalanceBefore = address(treasury).balance;
        uint256 userBalanceBefore = user.balance;

        uint256 partialTransferAmount = ETH_AMOUNT / 2;

        vm.prank(timelockOwner);

        treasury.transferEth(payable(user), partialTransferAmount);

        assertEq(
            user.balance,
            userBalanceBefore + partialTransferAmount,
            "Recipient balance should increase by exactly the requested partial amount"
        );

        assertEq(
            address(treasury).balance,
            treasuryBalanceBefore - partialTransferAmount,
            "Treasury balance should decrease by exactly the requested partial amount"
        );
    }
}
