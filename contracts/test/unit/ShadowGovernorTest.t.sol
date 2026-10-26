// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ShadowGovernor} from "../../src/ShadowGovernor.sol";
import {ShadowToken} from "../../src/ShadowToken.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract ShadowGovernorTest is Test {
    ShadowToken public shadowToken;
    TimelockController public timelockController;
    ShadowGovernor public shadowGovernor;

    address public deployer = makeAddr("deployer");
    address public belowThresholdProposer = makeAddr("belowThresholdProposer");
    address public thresholdProposer = makeAddr("thresholdProposer");
    address public forVoter = makeAddr("forVoter");
    address public againstVoter = makeAddr("againstVoter");
    address public abstainVoter = makeAddr("abstainVoter");
    address public ordinaryUser = makeAddr("ordinaryUser");

    string public constant GOVERNOR_NAME = "Shadow Governor";
    uint256 public constant TIMELOCK_DELAY = 2 minutes;
    uint8 public constant AGAINST_VOTE = 0;
    uint8 public constant FOR_VOTE = 1;
    uint8 public constant ABSTAIN_VOTE = 2;
    uint8 public constant INVALID_VOTE = 3;

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

    function test_GovernorNameMatchesSpecification() public view {
        assertEq(shadowGovernor.name(), "Shadow Governor", "Governor name should be Shadow Governor");
    }

    function test_VotingDelayMatchesSpecification() public view {
        assertEq(shadowGovernor.votingDelay(), 1 minutes, "Governor voting delay should be 1 minute");
    }

    function test_VotingPeriodMatchesSpecification() public view {
        assertEq(shadowGovernor.votingPeriod(), 5 minutes, "Governor voting period should be 5 minutes");
    }

    function test_ProposalThresholdMatchesSpecification() public view {
        assertEq(shadowGovernor.proposalThreshold(), 10_000e18, "Governor proposal threshold should equal 10,000 SHDW");
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

    function test_TimelockDelayMatchesSpecification() public view {
        assertEq(timelockController.getMinDelay(), 2 minutes, "timelock delay must be equal to 2 minutes");
    }

    function test_GovernorUsesConfiguredVotingToken() public view {
        assertEq(
            address(shadowGovernor.token()),
            address(shadowToken),
            "Governor voting token should match the deployed ShadowToken"
        );
    }

    function test_GovernorUsesConfiguredTimelock() public view {
        assertEq(
            address(shadowGovernor.timelock()),
            address(timelockController),
            "Governor timelock should match the deployed TimelockController"
        );
    }

    function test_GovernorUsesTimestampClock() public view {
        assertEq(shadowGovernor.CLOCK_MODE(), "mode=timestamp", "Governor clock mode should be timestamp");
        assertEq(shadowGovernor.clock(), block.timestamp, "Governor clock should equal the current block timestamp");
    }

    function test_GovernorRequiresProposalQueueing() public view {
        assertTrue(
            shadowGovernor.proposalNeedsQueuing(0), "Governor should require proposals to be queued before execution"
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

    ///////////////////////////
    /// Proposal Lifecycle ///
    /////////////////////////

    function test_ProposalBecomesActiveAfterVotingDelay() public {
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

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );
    }

    function test_ProposalBecomesDefeatedWhenVotingPeriodEndsWithoutVotes() public {
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

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "proposal should be Defeated after voting period ends without votes"
        );
    }

    function test_ProposalSucceedsWhenForVotesReachQuorumAndExceedAgainstVotes() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 quorum = shadowGovernor.QUORUM();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, quorum);
        assertTrue(success, "SHDW quorum transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created exactly at quorum");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded after voting period end"
        );
    }

    function test_ProposalDefeatedWhenAgainstVotesExceedForVotesDespiteQuorum() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;

        uint256 quorum = shadowGovernor.QUORUM();
        uint256 threshold = shadowGovernor.PROPOSAL_THRESHOLD();

        vm.startPrank(deployer);
        bool forVoterSuccess = shadowToken.transfer(forVoter, quorum);
        assertTrue(forVoterSuccess, "SHDW transfer of quorum to forVoter should succeed");

        bool againstVoterSuccess = shadowToken.transfer(againstVoter, quorum + 1);
        assertTrue(againstVoterSuccess, "SHDW transfer of quorum + 1 to againstVoter should succeed");

        bool success = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(success, "SHDW threshold transfer should succeed");
        vm.stopPrank();

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created at threshold");

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.prank(forVoter);
        shadowToken.delegate(forVoter);

        vm.prank(againstVoter);
        shadowToken.delegate(againstVoter);

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        vm.prank(forVoter);
        shadowGovernor.castVote(proposalId, FOR_VOTE);
        vm.prank(againstVoter);
        shadowGovernor.castVote(proposalId, AGAINST_VOTE);

        (againstVotes, forVotes, abstainVotes) = shadowGovernor.proposalVotes(proposalId);

        assertEq(forVotes, quorum, "for votes should be equal to quorum");
        assertEq(againstVotes, quorum + 1, "against votes should be equal to quorum + 1");
        assertEq(abstainVotes, 0, "abstain votes should be zero");

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "proposal state should be Defeated after voting period end"
        );
    }

    function test_ProposalDefeatedWhenForVotesFailToReachQuorum() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 threshold = shadowGovernor.PROPOSAL_THRESHOLD();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(success, "SHDW threshold transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created exactly at threshold");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "proposal state should be Defeated after voting period end as votes are below quorum"
        );
    }

    function test_ProposalDefeatedWhenForVotesAreOneUnitBelowQuorum() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 quorum = shadowGovernor.QUORUM();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, quorum - 1);
        assertTrue(success, "SHDW below-quorum transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId =
            shadowGovernor.propose(targets, values, calldatas, "Proposal created one unit below quorum");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "proposal state should be Defeated when total votes are one unit below quorum"
        );
    }

    function test_ProposalDefeatedWhenForAndAgainstVotesAreTied() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;

        uint256 quorum = shadowGovernor.QUORUM();
        uint256 threshold = shadowGovernor.PROPOSAL_THRESHOLD();

        vm.startPrank(deployer);
        bool forVoterSuccess = shadowToken.transfer(forVoter, quorum);
        assertTrue(forVoterSuccess, "SHDW transfer of quorum to forVoter should succeed");

        bool againstVoterSuccess = shadowToken.transfer(againstVoter, quorum);
        assertTrue(againstVoterSuccess, "SHDW transfer of quorum to againstVoter should succeed");

        bool success = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(success, "SHDW threshold transfer should succeed");
        vm.stopPrank();

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId =
            shadowGovernor.propose(targets, values, calldatas, "Proposal created at proposal threshold");

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.prank(forVoter);
        shadowToken.delegate(forVoter);

        vm.prank(againstVoter);
        shadowToken.delegate(againstVoter);

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        vm.prank(forVoter);
        shadowGovernor.castVote(proposalId, FOR_VOTE);
        vm.prank(againstVoter);
        shadowGovernor.castVote(proposalId, AGAINST_VOTE);

        (againstVotes, forVotes, abstainVotes) = shadowGovernor.proposalVotes(proposalId);

        assertEq(forVotes, quorum, "for votes should be equal to quorum");
        assertEq(againstVotes, quorum, "against votes should be equal to quorum");
        assertEq(abstainVotes, 0, "abstain votes should be zero");

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "proposal state should be Defeated when total votes for and against are tied"
        );
    }

    function test_ProposalSucceedsWhenForAndAbstainVotesReachQuorum() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 quorum = shadowGovernor.QUORUM();
        uint256 threshold = shadowGovernor.PROPOSAL_THRESHOLD();

        uint256 forVotes = quorum / 2;
        uint256 abstainVotes = quorum / 2;

        vm.startPrank(deployer);
        bool forVoterSuccess = shadowToken.transfer(forVoter, forVotes);
        assertTrue(forVoterSuccess, "SHDW transfer of half quorum to forVoter should succeed");

        bool abstainVoterSuccess = shadowToken.transfer(abstainVoter, abstainVotes);
        assertTrue(abstainVoterSuccess, "SHDW transfer of half quorum to abstainVoter should succeed");

        bool success = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(success, "SHDW threshold transfer should succeed");
        vm.stopPrank();

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId =
            shadowGovernor.propose(targets, values, calldatas, "Proposal created at proposal threshold");

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.prank(forVoter);
        shadowToken.delegate(forVoter);

        vm.prank(abstainVoter);
        shadowToken.delegate(abstainVoter);

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        vm.prank(forVoter);
        shadowGovernor.castVote(proposalId, FOR_VOTE);
        vm.prank(abstainVoter);
        shadowGovernor.castVote(proposalId, ABSTAIN_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded when for and abstain votes reach quorum"
        );
    }

    //////////////////////////////
    /// Proposal Cancellation ///
    ////////////////////////////

    function test_ProposerCanCancelPendingProposal() public {
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

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        bytes32 descriptionHash = keccak256(bytes("Proposal created exactly at threshold"));

        shadowGovernor.cancel(targets, values, calldatas, descriptionHash);

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Canceled),
            "proposal state should be Canceled after proposer calls cancel function"
        );
    }

    function test_NonProposerCannotCancelPendingProposal() public {
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

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.stopPrank();

        bytes32 descriptionHash = keccak256(bytes("Proposal created exactly at threshold"));

        vm.prank(ordinaryUser);

        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorUnableToCancel.selector, proposalId, ordinaryUser));

        shadowGovernor.cancel(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should remain in Pending state after non proposer attempts to cancel"
        );
    }

    function test_ProposerCannotCancelActiveProposal() public {
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

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        bytes32 descriptionHash = keccak256(bytes("Proposal created exactly at threshold"));

        vm.expectRevert(
            abi.encodeWithSelector(IGovernor.GovernorUnableToCancel.selector, proposalId, thresholdProposer)
        );

        shadowGovernor.cancel(targets, values, calldatas, descriptionHash);

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should remain in Active state after proposer attempts to cancel once proposal is Active"
        );
    }

    ///////////////
    /// Voting ///
    //////////////

    function test_ActiveProposalRecordsForVoteFromDelegatedProposer() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;

        uint256 threshold = shadowGovernor.PROPOSAL_THRESHOLD();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(success, "SHDW voting power transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created exactly at threshold");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        (againstVotes, forVotes, abstainVotes) = shadowGovernor.proposalVotes(proposalId);

        vm.stopPrank();

        assertEq(againstVotes, 0, "againstVotes should equal 0");
        assertEq(forVotes, threshold, "forVotes should equal the proposal threshold");
        assertEq(abstainVotes, 0, "abstainVotes should equal 0");
    }

    function test_ActiveProposalRecordsAgainstVoteFromDelegatedProposer() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;

        uint256 threshold = shadowGovernor.PROPOSAL_THRESHOLD();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(success, "SHDW voting power transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created exactly at threshold");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, AGAINST_VOTE);

        (againstVotes, forVotes, abstainVotes) = shadowGovernor.proposalVotes(proposalId);

        vm.stopPrank();

        assertEq(againstVotes, threshold, "againstVotes should equal the proposal threshold");
        assertEq(forVotes, 0, "forVotes should equal 0");
        assertEq(abstainVotes, 0, "abstainVotes should equal 0");
    }

    function test_ActiveProposalRecordsAbstainVoteFromDelegatedProposer() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;

        uint256 threshold = shadowGovernor.PROPOSAL_THRESHOLD();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(success, "SHDW voting power transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created exactly at threshold");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, ABSTAIN_VOTE);

        (againstVotes, forVotes, abstainVotes) = shadowGovernor.proposalVotes(proposalId);

        vm.stopPrank();

        assertEq(againstVotes, 0, "againstVotes should equal 0");
        assertEq(forVotes, 0, "forVotes should equal 0");
        assertEq(abstainVotes, threshold, "abstainVotes should equal the proposal threshold");
    }

    function test_VoterCannotCastMoreThanOneVote() public {
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

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorAlreadyCastVote.selector, thresholdProposer));

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.stopPrank();
    }

    function test_VoterCannotCastVoteWithInvalidSupportType() public {
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

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        vm.expectRevert(IGovernor.GovernorInvalidVoteType.selector);

        shadowGovernor.castVote(proposalId, INVALID_VOTE);

        vm.stopPrank();
    }

    function test_PendingProposalCannotReceiveVotes() public {
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

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        bytes32 expectedStates = bytes32(uint256(1) << uint8(IGovernor.ProposalState.Active));

        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorUnexpectedProposalState.selector,
                proposalId,
                IGovernor.ProposalState.Pending,
                expectedStates
            )
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.stopPrank();
    }

    function test_ProposalCannotReceiveVotesAfterVotingPeriodEnds() public {
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

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "proposal should be Defeated after voting period ends without votes"
        );

        bytes32 expectedStates = bytes32(uint256(1) << uint8(IGovernor.ProposalState.Active));

        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorUnexpectedProposalState.selector,
                proposalId,
                IGovernor.ProposalState.Defeated,
                expectedStates
            )
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.stopPrank();
    }

    function test_VotingWeightExcludesTokensReceivedAfterProposalSnapshot() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;

        uint256 threshold = shadowGovernor.PROPOSAL_THRESHOLD();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(success, "SHDW voting power transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created exactly at threshold");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        vm.stopPrank();

        vm.prank(deployer);

        bool secondTransferSuccess = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(secondTransferSuccess, "SHDW voting power transfer should succeed");

        assertEq(
            shadowToken.getVotes(thresholdProposer),
            threshold * 2,
            "threshold voting power should be double the threshold amount"
        );

        vm.prank(thresholdProposer);

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        (againstVotes, forVotes, abstainVotes) = shadowGovernor.proposalVotes(proposalId);

        assertEq(againstVotes, 0, "againstVotes should equal 0");
        assertEq(forVotes, threshold, "forVotes should equal the original proposal threshold");
        assertEq(abstainVotes, 0, "abstainVotes should equal 0");
    }

    function test_VotingWeightPreservedAfterPostSnapshotTokenTransfer() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;

        uint256 threshold = shadowGovernor.PROPOSAL_THRESHOLD();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(success, "SHDW voting power transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created exactly at threshold");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        uint256 amount = shadowToken.balanceOf(thresholdProposer);
        bool proposerTransferSuccess = shadowToken.transfer(ordinaryUser, amount);
        assertTrue(
            proposerTransferSuccess, "SHDW voting power transfer from proposer to separate address should succeed"
        );

        assertEq(shadowToken.getVotes(thresholdProposer), 0, "threshold voting power should be zero");

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        (againstVotes, forVotes, abstainVotes) = shadowGovernor.proposalVotes(proposalId);

        vm.stopPrank();

        assertEq(againstVotes, 0, "againstVotes should equal 0");
        assertEq(forVotes, threshold, "forVotes should equal the original proposal threshold");
        assertEq(abstainVotes, 0, "abstainVotes should equal 0");
    }

    function test_PostSnapshotTokenRecipientCannotReuseVotingPower() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;

        uint256 threshold = shadowGovernor.PROPOSAL_THRESHOLD();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, threshold);
        assertTrue(success, "SHDW voting power transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created exactly at threshold");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        uint256 amount = shadowToken.balanceOf(thresholdProposer);
        bool proposerTransferSuccess = shadowToken.transfer(ordinaryUser, amount);
        assertTrue(
            proposerTransferSuccess, "SHDW voting power transfer from proposer to separate address should succeed"
        );

        assertEq(shadowToken.getVotes(thresholdProposer), 0, "threshold voting power should be zero");

        vm.stopPrank();

        vm.startPrank(ordinaryUser);

        shadowToken.delegate(ordinaryUser);

        assertEq(shadowToken.getVotes(ordinaryUser), threshold, "test user voting power should equal threshold amount");

        uint256 postSnapshotVoteWeight = shadowGovernor.castVote(proposalId, FOR_VOTE);

        (againstVotes, forVotes, abstainVotes) = shadowGovernor.proposalVotes(proposalId);

        vm.stopPrank();

        assertEq(postSnapshotVoteWeight, 0, "test user vote weight should be zero for this proposal");

        assertEq(againstVotes, 0, "againstVotes should equal 0");
        assertEq(forVotes, threshold, "forVotes should equal the original proposal threshold");
        assertEq(abstainVotes, 0, "abstainVotes should equal 0");
    }

    //////////////////////////
    /// Timelock Queueing ///
    ////////////////////////

    function test_SucceededProposalCanBeQueuedInTimelock() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 quorum = shadowGovernor.QUORUM();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, quorum);
        assertTrue(success, "SHDW quorum transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created at exactly quorum");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded after voting period ends"
        );

        bytes32 descriptionHash = keccak256(bytes("Proposal created at exactly quorum"));

        shadowGovernor.queue(targets, values, calldatas, descriptionHash);

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued),
            "proposal state should be Queued"
        );
    }

    function test_SucceededProposalCanBeQueuedByAnyone() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 quorum = shadowGovernor.QUORUM();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, quorum);
        assertTrue(success, "SHDW quorum transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created at exactly quorum");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded after voting period ends"
        );

        vm.stopPrank();

        bytes32 descriptionHash = keccak256(bytes("Proposal created at exactly quorum"));

        vm.prank(ordinaryUser);

        shadowGovernor.queue(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued),
            "proposal state should be Queued"
        );
    }

    function test_DefeatedProposalCannotBeQueued() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 quorum = shadowGovernor.QUORUM();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, quorum - 1);
        assertTrue(success, "SHDW below-quorum transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId =
            shadowGovernor.propose(targets, values, calldatas, "Proposal created one unit below quorum");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "proposal state should be Defeated when total votes are one unit below quorum"
        );

        bytes32 expectedStates = bytes32(uint256(1) << uint8(IGovernor.ProposalState.Succeeded));

        bytes32 descriptionHash = keccak256(bytes("Proposal created one unit below quorum"));

        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorUnexpectedProposalState.selector,
                proposalId,
                IGovernor.ProposalState.Defeated,
                expectedStates
            )
        );

        shadowGovernor.queue(targets, values, calldatas, descriptionHash);

        vm.stopPrank();
    }

    function test_QueuedProposalEtaMatchesTimelockDelay() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 quorum = shadowGovernor.QUORUM();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, quorum);
        assertTrue(success, "SHDW quorum transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created at exactly quorum");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded after voting period ends"
        );

        bytes32 descriptionHash = keccak256(bytes("Proposal created at exactly quorum"));

        uint256 queueTimestamp = block.timestamp;

        shadowGovernor.queue(targets, values, calldatas, descriptionHash);

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued),
            "proposal state should be Queued"
        );

        assertEq(
            shadowGovernor.proposalEta(proposalId),
            queueTimestamp + 2 minutes,
            "Proposal ETA should equal queue timestamp plus two minutes"
        );
    }

    ///////////////////////////
    /// Timelock Execution ///
    /////////////////////////

    function test_QueuedProposalCannotExecuteBeforeTimelockDelay() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 quorum = shadowGovernor.QUORUM();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, quorum);
        assertTrue(success, "SHDW quorum transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created at exactly quorum");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded after voting period ends"
        );

        bytes32 descriptionHash = keccak256(bytes("Proposal created at exactly quorum"));

        shadowGovernor.queue(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued),
            "proposal state should be Queued"
        );

        bytes32 salt = bytes20(address(shadowGovernor)) ^ descriptionHash;
        bytes32 operationId = timelockController.hashOperationBatch(targets, values, calldatas, bytes32(0), salt);

        bytes32 expectedStates = bytes32(uint256(1) << uint8(TimelockController.OperationState.Ready));

        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockController.TimelockUnexpectedOperationState.selector, operationId, expectedStates
            )
        );

        shadowGovernor.execute(targets, values, calldatas, descriptionHash);

        vm.stopPrank();
    }

    function test_QueuedProposalCanExecuteAfterTimelockDelay() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 quorum = shadowGovernor.QUORUM();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, quorum);
        assertTrue(success, "SHDW quorum transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created at exactly quorum");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded after voting period ends"
        );

        bytes32 descriptionHash = keccak256(bytes("Proposal created at exactly quorum"));

        shadowGovernor.queue(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued),
            "proposal state should be Queued"
        );

        vm.warp(shadowGovernor.proposalEta(proposalId));

        shadowGovernor.execute(targets, values, calldatas, descriptionHash);

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed),
            "proposal state should be Executed after timelock delay"
        );
    }

    function test_ExecutedProposalCannotExecuteAgain() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 quorum = shadowGovernor.QUORUM();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, quorum);
        assertTrue(success, "SHDW quorum transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created at exactly quorum");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded after voting period ends"
        );

        bytes32 descriptionHash = keccak256(bytes("Proposal created at exactly quorum"));

        shadowGovernor.queue(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued),
            "proposal state should be Queued"
        );

        vm.warp(shadowGovernor.proposalEta(proposalId));

        shadowGovernor.execute(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed),
            "proposal state should be Executed after timelock delay"
        );

        bytes32 expectedStates = bytes32(uint256(1) << uint8(IGovernor.ProposalState.Queued));

        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorUnexpectedProposalState.selector,
                proposalId,
                IGovernor.ProposalState.Executed,
                expectedStates
            )
        );

        shadowGovernor.execute(targets, values, calldatas, descriptionHash);

        vm.stopPrank();
    }

    function test_QueuedProposalCanBeExecutedByAnyone() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 quorum = shadowGovernor.QUORUM();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, quorum);
        assertTrue(success, "SHDW quorum transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created at exactly quorum");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded after voting period ends"
        );

        bytes32 descriptionHash = keccak256(bytes("Proposal created at exactly quorum"));

        shadowGovernor.queue(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued),
            "proposal state should be Queued"
        );

        vm.stopPrank();

        vm.warp(shadowGovernor.proposalEta(proposalId));

        vm.prank(ordinaryUser);

        shadowGovernor.execute(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed),
            "proposal state should be Executed"
        );
    }

    function test_SucceededProposalCannotExecuteWithoutQueueing() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        uint256 quorum = shadowGovernor.QUORUM();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, quorum);
        assertTrue(success, "SHDW quorum transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Proposal created at exactly quorum");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded after voting period ends"
        );

        bytes32 descriptionHash = keccak256(bytes("Proposal created at exactly quorum"));

        bytes32 expectedStates = bytes32(uint256(1) << uint8(IGovernor.ProposalState.Queued));

        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorUnexpectedProposalState.selector,
                proposalId,
                IGovernor.ProposalState.Succeeded,
                expectedStates
            )
        );

        shadowGovernor.execute(targets, values, calldatas, descriptionHash);

        vm.stopPrank();
    }

    ////////////////////////////////
    /// Timelock Access Control ///
    //////////////////////////////

    function test_UnauthorizedUserCannotScheduleTimelockOperation() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(0x123);
        values[0] = 0;
        calldatas[0] = bytes("");

        bytes32 neededRole = timelockController.PROPOSER_ROLE();
        uint256 delay = timelockController.getMinDelay();

        vm.startPrank(ordinaryUser);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, ordinaryUser, neededRole)
        );

        timelockController.scheduleBatch(targets, values, calldatas, bytes32(0), bytes32(0), delay);

        vm.stopPrank();
    }

    ///////////////////////////////////////////
    /// Governance Settings Access Control ///
    /////////////////////////////////////////

    function test_OrdinaryUserCannotChangeVotingDelay() public {
        uint48 newVotingDelay = 2 minutes;

        vm.prank(ordinaryUser);

        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorOnlyExecutor.selector, ordinaryUser));

        shadowGovernor.setVotingDelay(newVotingDelay);

        assertEq(
            shadowGovernor.votingDelay(),
            shadowGovernor.VOTING_DELAY(),
            "voting delay should remain equal to shadowGovernor.VOTING_DELAY()"
        );
    }

    ////////////////////////////
    /// Governance Settings ///
    //////////////////////////

    function test_GovernanceCanChangeVotingDelayThroughTimelock() public {
        uint48 newVotingDelay = 2 minutes;

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(shadowGovernor);
        values[0] = 0;
        calldatas[0] = abi.encodeCall(shadowGovernor.setVotingDelay, (newVotingDelay));

        uint256 quorum = shadowGovernor.QUORUM();

        vm.prank(deployer);

        bool success = shadowToken.transfer(thresholdProposer, quorum);
        assertTrue(success, "SHDW quorum transfer should succeed");

        vm.startPrank(thresholdProposer);

        shadowToken.delegate(thresholdProposer);

        vm.warp(block.timestamp + 1);

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Change voting delay to two minutes");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(block.timestamp + shadowGovernor.VOTING_DELAY() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(block.timestamp + shadowGovernor.VOTING_PERIOD() + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded after voting period ends"
        );

        bytes32 descriptionHash = keccak256(bytes("Change voting delay to two minutes"));

        shadowGovernor.queue(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued),
            "proposal state should be Queued"
        );

        vm.warp(shadowGovernor.proposalEta(proposalId));

        shadowGovernor.execute(targets, values, calldatas, descriptionHash);

        vm.stopPrank();

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed),
            "proposal state should be Executed after timelock delay"
        );

        assertEq(
            shadowGovernor.votingDelay(),
            newVotingDelay,
            "shadowGovernor.votingDelay() should equal new voting delay of 2 minutes"
        );
    }
}
