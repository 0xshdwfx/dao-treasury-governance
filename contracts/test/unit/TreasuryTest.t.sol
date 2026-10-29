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

    function setUp() public {
        treasury = new Treasury(timelockOwner);
    }

    ///////////////////
    /// Deployment ///
    /////////////////

    function test_OwnerMatchesConfiguredTimelock() public view {
        assertEq(treasury.owner(), timelockOwner, "treasury owner must equal Timelock address");
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

        assertEq(treasury.owner(), timelockOwner, "treasury ownership should still equal timelock address");
    }

    function test_TimelockOwnerCannotRenounceOwnership() public {
        vm.prank(timelockOwner);

        vm.expectRevert(Treasury.Treasury__OwnershipChangeDisabled.selector);

        treasury.renounceOwnership();

        assertEq(treasury.owner(), timelockOwner, "treasury ownership should still equal timelock address");
    }
}
