// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ShadowToken} from "./ShadowToken.sol";
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract ShadowGovernor is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorTimelockControl {
    ////////////////////////
    /// State Variables ///
    ///////////////////////

    ShadowToken public immutable SHADOW_TOKEN;

    uint256 public constant QUORUM = 40_000e18;
    uint256 public constant PROPOSAL_THRESHOLD = 10_000e18;
    uint48 public constant VOTING_DELAY = 1 minutes;
    uint32 public constant VOTING_PERIOD = 5 minutes;
    uint256 public constant TIMELOCK_DELAY = 2 minutes;

    ////////////////////
    /// Constructor ///
    ///////////////////

    constructor(string memory name_, ShadowToken shadowToken, TimelockController timelockAddress)
        Governor(name_)
        GovernorSettings(VOTING_DELAY, VOTING_PERIOD, PROPOSAL_THRESHOLD)
        GovernorVotes(shadowToken)
        GovernorTimelockControl(timelockAddress)
    {
        SHADOW_TOKEN = shadowToken;
    }

    ///////////////
    /// Quorum ///
    //////////////

    function quorum(uint256) public view override returns (uint256) {
        return QUORUM;
    }

    ///////////////////////////
    /// Function Overrides ///
    //////////////////////////

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view virtual override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        virtual
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold() public view virtual override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function state(uint256 proposalId)
        public
        view
        virtual
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }
}
