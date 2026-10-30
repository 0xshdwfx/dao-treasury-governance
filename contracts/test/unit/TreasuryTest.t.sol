// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Treasury} from "../../src/Treasury.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TreasuryTest is Test {
    Treasury public treasury;

    address public timelockOwner = makeAddr("timelockOwner");
    address public user = makeAddr("user");
    address public recipient = makeAddr("recipient");

    uint256 public constant ETH_AMOUNT = 1e18;

    // events
    event EthTransferred(address indexed recipient, uint256 amount);

    function setUp() public {
        treasury = new Treasury(timelockOwner);
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
}
