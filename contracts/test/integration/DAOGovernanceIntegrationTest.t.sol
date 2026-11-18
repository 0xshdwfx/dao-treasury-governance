// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ShadowToken} from "../../src/ShadowToken.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ShadowGovernor} from "../../src/ShadowGovernor.sol";
import {Treasury} from "../../src/Treasury.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract DAOGovernanceIntegrationTest is Test {
    ShadowToken public shadowToken;
    TimelockController public timelockController;
    ShadowGovernor public shadowGovernor;
    Treasury public treasury;

    address public proposer = makeAddr("proposer");
    address public recipient = makeAddr("recipient");
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

        shadowToken = new ShadowToken();
        timelockController = new TimelockController(TIMELOCK_DELAY, proposers, executors, address(this));
        shadowGovernor = new ShadowGovernor(GOVERNOR_NAME, shadowToken, timelockController);
        treasury = new Treasury(address(timelockController));

        bytes32 proposerRole = timelockController.PROPOSER_ROLE();
        timelockController.grantRole(proposerRole, address(shadowGovernor));

        bytes32 adminRole = timelockController.DEFAULT_ADMIN_ROLE();
        timelockController.renounceRole(adminRole, address(this));
    }

    function test_ConfigureDAO_AssignsTreasuryOwnershipAndTimelockRoles() public view {
        bytes32 proposerRole = timelockController.PROPOSER_ROLE();
        bytes32 executorRole = timelockController.EXECUTOR_ROLE();
        bytes32 defaultAdminRole = timelockController.DEFAULT_ADMIN_ROLE();

        assertEq(
            treasury.owner(), address(timelockController), "Treasury owner should be the deployed TimelockController"
        );

        assertTrue(timelockController.hasRole(executorRole, address(0)), "Timelock execution should be open to anyone");

        assertTrue(
            timelockController.hasRole(defaultAdminRole, address(timelockController)),
            "Timelock should retain its own admin role"
        );

        assertTrue(
            timelockController.hasRole(proposerRole, address(shadowGovernor)),
            "Governor should have permission to schedule Timelock operations"
        );

        assertFalse(
            timelockController.hasRole(proposerRole, address(this)),
            "Test contract should not have permission to schedule Timelock operations"
        );

        assertFalse(
            timelockController.hasRole(defaultAdminRole, address(this)),
            "Test contract should no longer hold the temporary Timelock admin role"
        );
    }

    function test_ExecuteProposal_TransfersTreasuryETH_WhenApprovedAndTimelockDelayHasElapsed() public {
        uint256 ethAmount = 1 ether;

        deal(address(treasury), ethAmount);

        uint256 treasuryEthBalanceBefore = address(treasury).balance;
        uint256 recipientEthBalanceBefore = recipient.balance;

        uint256 quorum = shadowGovernor.QUORUM();

        bool success = shadowToken.transfer(proposer, quorum);
        assertTrue(success, "SHDW quorum transfer should succeed");

        vm.startPrank(proposer);
        shadowToken.delegate(proposer);

        vm.warp(block.timestamp + 1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeCall(treasury.transferEth, (payable(recipient), ethAmount));

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Transfer 1 ether to recipient");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(shadowGovernor.proposalSnapshot(proposalId) + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(shadowGovernor.proposalDeadline(proposalId) + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded after voting period ends"
        );

        bytes32 descriptionHash = keccak256(bytes("Transfer 1 ether to recipient"));

        shadowGovernor.queue(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued),
            "proposal state should be Queued"
        );

        vm.warp(shadowGovernor.proposalEta(proposalId));

        vm.stopPrank();

        vm.prank(ordinaryUser);

        shadowGovernor.execute(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed),
            "proposal state should be Executed after timelock delay"
        );

        uint256 treasuryEthBalanceAfter = address(treasury).balance;
        uint256 recipientEthBalanceAfter = recipient.balance;

        assertEq(
            treasuryEthBalanceAfter,
            treasuryEthBalanceBefore - ethAmount,
            "Treasury ETH balance should decrease by the approved amount"
        );
        assertEq(
            recipientEthBalanceAfter,
            recipientEthBalanceBefore + ethAmount,
            "Recipient ETH balance should increase by the approved amount"
        );
    }

    function test_ExecuteProposal_TransfersTreasuryERC20_WhenApprovedAndTimelockDelayHasElapsed() public {
        uint256 transferAmount = 100e18;

        bool transferSuccess = shadowToken.transfer(address(treasury), transferAmount);
        assertTrue(transferSuccess, "SHDW token transfer to Treasury should succeed");

        uint256 treasuryTokenBalanceBefore = shadowToken.balanceOf(address(treasury));
        uint256 recipientTokenBalanceBefore = shadowToken.balanceOf(address(recipient));

        uint256 quorum = shadowGovernor.QUORUM();

        bool success = shadowToken.transfer(proposer, quorum);
        assertTrue(success, "SHDW quorum transfer should succeed");

        vm.startPrank(proposer);
        shadowToken.delegate(proposer);

        vm.warp(block.timestamp + 1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] =
            abi.encodeCall(treasury.transferERC20, (address(shadowToken), address(recipient), transferAmount));

        uint256 proposalId = shadowGovernor.propose(targets, values, calldatas, "Transfer 100 SHDW to recipient");

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Pending),
            "proposal should start in Pending state"
        );

        vm.warp(shadowGovernor.proposalSnapshot(proposalId) + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "proposal should be Active after voting delay"
        );

        shadowGovernor.castVote(proposalId, FOR_VOTE);

        vm.warp(shadowGovernor.proposalDeadline(proposalId) + 1);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "proposal state should be Succeeded after voting period ends"
        );

        bytes32 descriptionHash = keccak256(bytes("Transfer 100 SHDW to recipient"));

        shadowGovernor.queue(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued),
            "proposal state should be Queued"
        );

        vm.warp(shadowGovernor.proposalEta(proposalId));

        vm.stopPrank();

        vm.prank(ordinaryUser);

        shadowGovernor.execute(targets, values, calldatas, descriptionHash);

        assertEq(
            uint256(shadowGovernor.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed),
            "proposal state should be Executed after timelock delay"
        );

        uint256 treasuryTokenBalanceAfter = shadowToken.balanceOf(address(treasury));
        uint256 recipientTokenBalanceAfter = shadowToken.balanceOf(address(recipient));

        assertEq(
            treasuryTokenBalanceAfter,
            treasuryTokenBalanceBefore - transferAmount,
            "Treasury SHDW balance should decrease by the approved amount"
        );
        assertEq(
            recipientTokenBalanceAfter,
            recipientTokenBalanceBefore + transferAmount,
            "Recipient SHDW balance should increase by the approved amount"
        );
    }
}
