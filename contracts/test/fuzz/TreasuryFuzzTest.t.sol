// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../src/Treasury.sol";

contract TreasuryFuzzTest is Test {
    Treasury public treasury;

    address public timelockOwner = makeAddr("timelockOwner");
    address public recipient = makeAddr("recipient");

    function setUp() public {
        treasury = new Treasury(timelockOwner);
    }
}
