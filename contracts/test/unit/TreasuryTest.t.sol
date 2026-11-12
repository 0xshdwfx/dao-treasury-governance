// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Treasury} from "../../src/Treasury.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RejectingETHRecipient} from "../mocks/RejectingETHRecipient.sol";
import {ShadowToken} from "../../src/ShadowToken.sol";
import {FalseReturnERC20} from "../mocks/FalseReturnERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {NoReturnERC20} from "../mocks/NoReturnERC20.sol";

contract TreasuryTest is Test {
    Treasury public treasury;
    RejectingETHRecipient public rejectingEthRecipient;
    ShadowToken public shadowToken;
    FalseReturnERC20 public falseReturnERC20;
    NoReturnERC20 public noReturnERC20;

    address public timelockOwner = makeAddr("timelockOwner");
    address public user = makeAddr("user");
    address public recipient = makeAddr("recipient");
    address public tokenDeployer = makeAddr("tokenDeployer");

    uint256 public constant ETH_AMOUNT = 1e18;
    uint256 public constant TRANSFER_AMOUNT = 100e18;

    // events
    event EthTransferred(address indexed recipient, uint256 amount);
    event ERC20Transferred(address indexed token, address indexed recipient, uint256 requestedAmount);

    function setUp() public {
        treasury = new Treasury(timelockOwner);
        rejectingEthRecipient = new RejectingETHRecipient();
        falseReturnERC20 = new FalseReturnERC20();
        noReturnERC20 = new NoReturnERC20();

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
        uint256 rejectingEthRecipientBalanceBefore = address(rejectingEthRecipient).balance;

        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__EthTransferFailed.selector);

        treasury.transferEth(payable(address(rejectingEthRecipient)), ETH_AMOUNT);

        assertEq(address(treasury).balance, treasuryBalanceBefore, "Treasury balance should remain unchanged");

        assertEq(
            address(rejectingEthRecipient).balance,
            rejectingEthRecipientBalanceBefore,
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

    /////////////////////////
    /// ERC-20 Transfers ///
    ///////////////////////

    function test_WithdrawTreasuryERC20_TransfersRequestedAmount_WhenCalledByTimelockOwner() public {
        deal(address(shadowToken), address(treasury), TRANSFER_AMOUNT);
        uint256 treasuryBalanceBefore = shadowToken.balanceOf(address(treasury));
        uint256 userBalanceBefore = shadowToken.balanceOf(user);

        vm.expectEmit(true, true, false, true, address(treasury));
        emit ERC20Transferred(address(shadowToken), user, TRANSFER_AMOUNT);

        vm.prank(timelockOwner);

        treasury.transferERC20(address(shadowToken), user, TRANSFER_AMOUNT);

        uint256 treasuryBalanceAfter = shadowToken.balanceOf(address(treasury));
        uint256 userBalanceAfter = shadowToken.balanceOf(user);

        assertEq(
            treasuryBalanceAfter,
            treasuryBalanceBefore - TRANSFER_AMOUNT,
            "Treasury balance should decrease by the transferred amount"
        );

        assertEq(
            userBalanceAfter,
            userBalanceBefore + TRANSFER_AMOUNT,
            "Recipient balance should increase by transferred amount"
        );
    }

    function test_WithdrawTreasuryERC20_Reverts_WhenCalledByOrdinaryUser() public {
        deal(address(shadowToken), address(treasury), TRANSFER_AMOUNT);
        uint256 treasuryBalanceBefore = shadowToken.balanceOf(address(treasury));
        uint256 userBalanceBefore = shadowToken.balanceOf(user);

        vm.prank(user);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));

        treasury.transferERC20(address(shadowToken), user, TRANSFER_AMOUNT);

        uint256 treasuryBalanceAfter = shadowToken.balanceOf(address(treasury));
        uint256 userBalanceAfter = shadowToken.balanceOf(user);

        assertEq(treasuryBalanceAfter, treasuryBalanceBefore, "Treasury balance should remain unchanged");

        assertEq(userBalanceAfter, userBalanceBefore, "User balance should remain unchanged");
    }

    function test_WithdrawTreasuryERC20_Reverts_WhenTokenAddressIsZero() public {
        deal(address(shadowToken), address(treasury), TRANSFER_AMOUNT);
        uint256 treasuryBalanceBefore = shadowToken.balanceOf(address(treasury));
        uint256 userBalanceBefore = shadowToken.balanceOf(user);

        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__InvalidTokenAddress.selector);

        treasury.transferERC20(address(0), user, TRANSFER_AMOUNT);

        uint256 treasuryBalanceAfter = shadowToken.balanceOf(address(treasury));
        uint256 userBalanceAfter = shadowToken.balanceOf(user);

        assertEq(treasuryBalanceAfter, treasuryBalanceBefore, "Treasury balance should remain unchanged");

        assertEq(userBalanceAfter, userBalanceBefore, "User balance should remain unchanged");
    }

    function test_WithdrawTreasuryERC20_Reverts_WhenRecipientIsZeroAddress() public {
        deal(address(shadowToken), address(treasury), TRANSFER_AMOUNT);
        uint256 treasuryBalanceBefore = shadowToken.balanceOf(address(treasury));

        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__InvalidRecipient.selector);

        treasury.transferERC20(address(shadowToken), address(0), TRANSFER_AMOUNT);

        uint256 treasuryBalanceAfter = shadowToken.balanceOf(address(treasury));

        assertEq(treasuryBalanceAfter, treasuryBalanceBefore, "Treasury balance should remain unchanged");
    }

    function test_WithdrawTreasuryERC20_Reverts_WhenAmountIsZero() public {
        deal(address(shadowToken), address(treasury), TRANSFER_AMOUNT);
        uint256 treasuryBalanceBefore = shadowToken.balanceOf(address(treasury));
        uint256 userBalanceBefore = shadowToken.balanceOf(user);

        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__InvalidTransferAmount.selector);

        treasury.transferERC20(address(shadowToken), user, 0);

        uint256 treasuryBalanceAfter = shadowToken.balanceOf(address(treasury));
        uint256 userBalanceAfter = shadowToken.balanceOf(user);

        assertEq(treasuryBalanceAfter, treasuryBalanceBefore, "Treasury balance should remain unchanged");

        assertEq(userBalanceAfter, userBalanceBefore, "User balance should remain unchanged");
    }

    function test_WithdrawTreasuryERC20_Reverts_WhenAmountExceedsTreasuryTokenBalance() public {
        deal(address(shadowToken), address(treasury), TRANSFER_AMOUNT);
        uint256 treasuryBalanceBefore = shadowToken.balanceOf(address(treasury));
        uint256 userBalanceBefore = shadowToken.balanceOf(user);

        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__TransferAmountExceedsTokenBalance.selector);

        treasury.transferERC20(address(shadowToken), user, TRANSFER_AMOUNT + 1);

        uint256 treasuryBalanceAfter = shadowToken.balanceOf(address(treasury));
        uint256 userBalanceAfter = shadowToken.balanceOf(user);

        assertEq(treasuryBalanceAfter, treasuryBalanceBefore, "Treasury balance should remain unchanged");

        assertEq(userBalanceAfter, userBalanceBefore, "User balance should remain unchanged");
    }

    /////////////////////////////////
    /// ERC-20 Transfer Failures ///
    ///////////////////////////////

    function test_WithdrawTreasuryERC20_Reverts_WhenTokenTransferReturnsFalse() public {
        deal(address(falseReturnERC20), address(treasury), TRANSFER_AMOUNT);
        uint256 treasuryBalanceBefore = falseReturnERC20.balanceOf(address(treasury));
        uint256 userBalanceBefore = falseReturnERC20.balanceOf(user);

        vm.prank(timelockOwner);

        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(falseReturnERC20)));

        treasury.transferERC20(address(falseReturnERC20), user, TRANSFER_AMOUNT);

        uint256 treasuryBalanceAfter = falseReturnERC20.balanceOf(address(treasury));
        uint256 userBalanceAfter = falseReturnERC20.balanceOf(user);

        assertEq(treasuryBalanceAfter, treasuryBalanceBefore, "Treasury balance should remain unchanged");

        assertEq(userBalanceAfter, userBalanceBefore, "User balance should remain unchanged");
    }

    ////////////////////////////
    /// ERC-20 Compatibility ///
    ///////////////////////////

    function test_WithdrawTreasuryERC20_TransfersRequestedAmount_WhenTokenReturnsNoData() public {
        deal(address(noReturnERC20), address(treasury), TRANSFER_AMOUNT);
        uint256 treasuryBalanceBefore = noReturnERC20.balanceOf(address(treasury));
        uint256 userBalanceBefore = noReturnERC20.balanceOf(user);

        vm.expectEmit(true, true, false, true, address(treasury));
        emit ERC20Transferred(address(noReturnERC20), user, TRANSFER_AMOUNT);

        vm.prank(timelockOwner);

        treasury.transferERC20(address(noReturnERC20), user, TRANSFER_AMOUNT);

        uint256 treasuryBalanceAfter = noReturnERC20.balanceOf(address(treasury));
        uint256 userBalanceAfter = noReturnERC20.balanceOf(user);

        assertEq(
            treasuryBalanceAfter,
            treasuryBalanceBefore - TRANSFER_AMOUNT,
            "Treasury balance should decrease by transfer amount"
        );

        assertEq(
            userBalanceAfter, userBalanceBefore + TRANSFER_AMOUNT, "User balance should increase by transfer amount"
        );
    }
}
