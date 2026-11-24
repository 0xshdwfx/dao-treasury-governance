// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../../src/Treasury.sol";

contract TreasuryHandler is Test {
    Treasury public immutable TREASURY;
    address public immutable TIMELOCK_OWNER;
    address public recipient = makeAddr("recipient");

    uint256 public totalEthDeposited;
    uint256 public totalEthWithdrawn;

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

    function withdrawEth(uint256 amount) external {
        uint256 treasuryEthBalance = address(TREASURY).balance;

        if (treasuryEthBalance == 0) return;

        amount = bound(amount, 1 wei, treasuryEthBalance);

        vm.prank(TIMELOCK_OWNER);

        TREASURY.transferEth(payable(recipient), amount);

        totalEthWithdrawn += amount;
    }
}
