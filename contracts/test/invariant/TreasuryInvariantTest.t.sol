// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../src/Treasury.sol";

contract TreasuryInvariantTest is Test {
    Treasury public treasury;

    address public timelockOwner = makeAddr("timelockOwner");

    function setUp() public {
        treasury = new Treasury(timelockOwner);
    }
}
