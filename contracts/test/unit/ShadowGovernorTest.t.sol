// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ShadowGovernor} from "../../src/ShadowGovernor.sol";
import {ShadowToken} from "../../src/ShadowToken.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract ShadowGovernorTest is Test {
    ShadowToken public shadowToken;
    TimelockController public timelockController;
    ShadowGovernor public shadowGovernor;

    address public deployer = makeAddr("deployer");
    address public belowThresholdProposer = makeAddr("belowThresholdProposer");
    address public thresholdProposer = makeAddr("thresholdProposer");

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

    function test_QuorumMatchesSpecification() public view {
        assertEq(shadowGovernor.QUORUM(), 40_000e18, "Governor quorum should equal 40,000 voting units");
    }

    function test_QuorumFunctionReturnsFixedQuorum() public view {
        assertEq(shadowGovernor.quorum(0), shadowGovernor.QUORUM(), "Quorum function should return 40,000 voting units");
        assertEq(
            shadowGovernor.quorum(1000), shadowGovernor.QUORUM(), "Quorum function should return 40,000 voting units"
        );
        assertEq(
            shadowGovernor.quorum(1_000_000),
            shadowGovernor.QUORUM(),
            "Quorum function should return 40,000 voting units"
        );
    }

    ////////////////////////////
    /// Proposal Validation ///
    //////////////////////////

    function test_ProposalCreationRevertsBelowThreshold() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorInsufficientProposerVotes.selector,
                belowThresholdProposer,
                0,
                shadowGovernor.PROPOSAL_THRESHOLD()
            )
        );

        vm.prank(belowThresholdProposer);

        shadowGovernor.propose(targets, values, calldatas, "Proposal created below threshold");
    }

    function test_ProposalCreationSucceedsAtThreshold() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 threshold = shadowGovernor.PROPOSAL_THRESHOLD();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(success, "SHDW voting power transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created exactly at threshold");

        vm.stopPrank();

        assertGt(proposalId, 0, "proposal ID should be greater than zero");
    }

    function test_ProposalCreatedAtThresholdStartsInPendingState() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 threshold = shadowGovernor.PROPOSAL_THRESHOLD();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(success, "SHDW voting power transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created exactly at threshold");

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );
    }
}
