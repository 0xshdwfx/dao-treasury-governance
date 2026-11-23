// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../../src/Treasury.sol";

contract TreasuryHandler is Test {
    Treasury public immutable TREASURY;
    address public immutable TIMELOCK_OWNER;

    constructor(Treasury _treasury, address _timelockOwner) {
        TREASURY = _treasury;
        TIMELOCK_OWNER = _timelockOwner;
    }
}
