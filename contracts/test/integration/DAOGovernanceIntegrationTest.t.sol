// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ShadowToken} from "../../src/ShadowToken.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ShadowGovernor} from "../../src/ShadowGovernor.sol";
import {Treasury} from "../../src/Treasury.sol";

contract DAOGovernanceIntegrationTest is Test {
    ShadowToken public shadowToken;
    TimelockController public timelockController;
    ShadowGovernor public shadowGovernor;
    Treasury public treasury;

    string public constant GOVERNOR_NAME = "Shadow Governor";
    uint256 public constant TIMELOCK_DELAY = 2 minutes;

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
}
