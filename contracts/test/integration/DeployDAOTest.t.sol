// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ShadowToken} from "../../src/ShadowToken.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ShadowGovernor} from "../../src/ShadowGovernor.sol";
import {Treasury} from "../../src/Treasury.sol";
import {DeployDAO} from "../../script/DeployDAO.s.sol";

contract DeployDAOTest is Test {
    ShadowToken public shadowToken;
    TimelockController public timelock;
    ShadowGovernor public shadowGovernor;
    Treasury public treasury;

    function setUp() public {
        DeployDAO deployDAO = new DeployDAO();

        (shadowToken, timelock, shadowGovernor, treasury) = deployDAO.run();
    }

    function test_DeployDAO_AssignsTreasuryOwnershipToTimelock() public view {
        assertEq(treasury.owner(), address(timelock), "Treasury owner should be the Timelock");
    }

    function test_DeployDAO_GrantsGovernorProposerRole() public view {
        assertTrue(
            timelock.hasRole(timelock.PROPOSER_ROLE(), address(shadowGovernor)),
            "Governor should have the Timelock proposer role"
        );
    }

    function test_DeployDAO_GrantsGovernorCancellerRole() public view {
        assertTrue(
            timelock.hasRole(timelock.CANCELLER_ROLE(), address(shadowGovernor)),
            "Governor should have the Timelock canceller role"
        );
    }

    function test_DeployDAO_OpensTimelockExecution() public view {
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)), "Timelock executor role should be open");
    }

    function test_DeployDAO_RemovesDeployerAdminRole() public view {
        assertFalse(
            timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(this)),
            "Deployer should not retain the Timelock admin role"
        );
    }

    function test_DeployDAO_KeepsTimelockAdminRole() public view {
        assertTrue(
            timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock)),
            "Timelock should retain its own admin role"
        );
    }

    function test_DeployDAO_SetsTwoMinuteTimelockDelay() public view {
        assertEq(timelock.getMinDelay(), 2 minutes, "Timelock minimum delay should be two minutes");
    }

    function test_DeployDAO_ConnectsGovernorToShadowToken() public view {
        assertEq(
            address(shadowGovernor.token()),
            address(shadowToken),
            "Governor voting token should be the deployed ShadowToken"
        );
    }

    function test_DeployDAO_ConnectsGovernorToTimelock() public view {
        assertEq(
            address(shadowGovernor.timelock()), address(timelock), "Governor timelock should be the deployed Timelock"
        );
    }

    function test_DeployDAO_AllocatesEntireTokenSupplyToDeployer() public view {
        assertEq(
            shadowToken.balanceOf(address(this)), 1_000_000e18, "Deployer should receive the entire initial SHDW supply"
        );
    }
}
