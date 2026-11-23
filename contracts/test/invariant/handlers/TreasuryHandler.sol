// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../../src/Treasury.sol";

contract TreasuryHandler is Test {
    Treasury public immutable TREASURY;
    address public immutable TIMELOCK_OWNER;

    uint256 public totalEthDeposited;

    constructor(Treasury _treasury, address _timelockOwner) {
        TREASURY = _treasury;
        TIMELOCK_OWNER = _timelockOwner;
    }

    function depositEth(uint256 amount) external {
        amount = bound(amount, 1 wei, 100 ether);

        deal(address(this), amount);

        (bool success,) = address(TREASURY).call{value: amount}("");
        assertTrue(success, "ETH transfer to TREASURY should succeed");

        totalEthDeposited += amount;
    }
}
