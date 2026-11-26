// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {ShadowToken} from "../src/ShadowToken.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ShadowGovernor} from "../src/ShadowGovernor.sol";
import {Treasury} from "../src/Treasury.sol";

contract DeployDAO is Script {
    function run()
        external
        returns (ShadowToken shadowToken, TimelockController timelock, ShadowGovernor shadowGovernor, Treasury treasury)
    {
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        vm.startBroadcast();

        shadowToken = new ShadowToken();
        timelock = new TimelockController(2 minutes, proposers, executors, msg.sender);
        shadowGovernor = new ShadowGovernor("ShadowGovernor", shadowToken, timelock);
        treasury = new Treasury(address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(shadowGovernor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(shadowGovernor));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), msg.sender);

        vm.stopBroadcast();
    }
}
