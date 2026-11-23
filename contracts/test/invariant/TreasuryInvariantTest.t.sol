// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../src/Treasury.sol";
import {TreasuryHandler} from "./handlers/TreasuryHandler.sol";

contract TreasuryInvariantTest is Test {
    Treasury public treasury;
    TreasuryHandler public handler;

    address public timelockOwner = makeAddr("timelockOwner");

    function setUp() public {
        treasury = new Treasury(timelockOwner);

        handler = new TreasuryHandler(treasury, timelockOwner);
    }
}
