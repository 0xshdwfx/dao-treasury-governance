// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../src/Treasury.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TreasuryTest is Test {
    Treasury public treasury;

    address public timelockOwner = makeAddr("timelockOwner");
    address public user = makeAddr("user");
    address public recipient = makeAddr("recipient");

    uint256 public constant ETH_AMOUNT = 1e18;

    function setUp() public {
        treasury = new Treasury(timelockOwner);
    }

    ///////////////////
    /// Deployment ///
    /////////////////

    function test_OwnerMatchesConfiguredTimelock() public view {
        assertEq(treasury.owner(), timelockOwner, "Treasury owner must equal Timelock address");
    }

    function test_DeploymentRevertsWithZeroTimelockAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new Treasury(address(0));
    }

    ///////////////////////////////
    /// Ownership Restrictions ///
    /////////////////////////////

    function test_TimelockOwnerCannotTransferOwnership() public {
        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__OwnershipChangeDisabled.selector);

        treasury.transferOwnership(user);

        assertEq(treasury.owner(), timelockOwner, "Treasury ownership should still equal timelock address");
    }

    function test_TimelockOwnerCannotRenounceOwnership() public {
        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__OwnershipChangeDisabled.selector);

        treasury.renounceOwnership();

        assertEq(treasury.owner(), timelockOwner, "Treasury ownership should still equal timelock address");
    }

    ///////////////////////
    /// Asset Deposits ///
    /////////////////////

    function test_TreasuryAcceptsETHFromOrdinaryUser() public {
        deal(user, 10 ether);

        vm.prank(user);

        (bool success,) = address(treasury).call{value: ETH_AMOUNT}("");
        assertTrue(success, "ETH transfer to receive() should succeed");

        assertEq(address(treasury).balance, ETH_AMOUNT, "Treasury ETH balance should increase by deposited amount");
    }
}
