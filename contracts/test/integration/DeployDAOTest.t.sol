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
}
