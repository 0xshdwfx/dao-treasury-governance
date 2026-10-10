// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ShadowGovernor} from "../../src/ShadowGovernor.sol";
import {ShadowToken} from "../../src/ShadowToken.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract ShadowGovernorTest is Test {
    ShadowToken public shadowToken;
    TimelockController public timelockController;
    ShadowGovernor public shadowGovernor;

    address public deployer = makeAddr("deployer");

    string public constant GOVERNOR_NAME = "Shadow Governor";
    uint256 public constant TIMELOCK_DELAY = 2 minutes;

    function setUp() public {
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        vm.prank(deployer);
        shadowToken = new ShadowToken();

        vm.prank(deployer);
        timelockController = new TimelockController(TIMELOCK_DELAY, proposers, executors, address(this));

        vm.prank(deployer);
        shadowGovernor = new ShadowGovernor(GOVERNOR_NAME, shadowToken, timelockController);

        timelockController.grantRole(timelockController.PROPOSER_ROLE(), address(shadowGovernor));
    }

    ///////////////////////////////
    /// Governor Configuration ///
    /////////////////////////////

    function test_GovernorNameMatchesSpecification() public pure {
        assertEq(GOVERNOR_NAME, "Shadow Governor", "Governor name should be Shadow Governor");
    }

    function test_VotingDelayMatchesSpecification() public view {
        assertEq(shadowGovernor.VOTING_DELAY(), 1 minutes, "Governor voting delay should be 1 minute");
    }

    function test_VotingPeriodMatchesSpecification() public view {
        assertEq(shadowGovernor.VOTING_PERIOD(), 5 minutes, "Governor voting period should be 5 minutes");
    }

    function test_ProposalThresholdMatchesSpecification() public view {
        assertEq(shadowGovernor.PROPOSAL_THRESHOLD(), 10_000e18, "Governor proposal threshold should equal 10,000 SHDW");
    }
}
