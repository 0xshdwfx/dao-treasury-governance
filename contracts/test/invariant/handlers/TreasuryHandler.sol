// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../../src/Treasury.sol";
import {ShadowToken} from "../../../src/ShadowToken.sol";

contract TreasuryHandler is Test {
    Treasury public immutable TREASURY;
    ShadowToken public immutable SHADOW_TOKEN;
    address public immutable TIMELOCK_OWNER;
    address public recipient = makeAddr("recipient");

    uint256 public totalEthDeposited;
    uint256 public totalEthWithdrawn;
    uint256 public totalTokenDeposited;
    uint256 public totalTokenWithdrawn;

    constructor(Treasury _treasury, address _timelockOwner, ShadowToken _shadowToken) {
        TREASURY = _treasury;
        TIMELOCK_OWNER = _timelockOwner;
        SHADOW_TOKEN = _shadowToken;
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
