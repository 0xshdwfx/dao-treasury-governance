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

    function depositToken(uint256 amount) external {
        uint256 handlerTokenBalance = SHADOW_TOKEN.balanceOf(address(this));

        if (handlerTokenBalance == 0) return;

        amount = bound(amount, 1, handlerTokenBalance);

        bool success = SHADOW_TOKEN.transfer(address(TREASURY), amount);
        assertTrue(success, "SHDW token transfer from handler to Treasury should succeed");

        totalTokenDeposited += amount;
    }

    /**
     * @notice Withdraws a bounded SHDW amount as the authorised Treasury owner.
     * @dev Returns tokens to this handler so subsequent generated actions can
     *      deposit them again, preventing token exhaustion from reducing the
     *      campaign to no-op calls. This is a test-harness choice for exercising
     *      Treasury accounting, not a production withdrawal-recipient policy.
     */
    function withdrawToken(uint256 amount) external {
        uint256 treasuryTokenBalance = SHADOW_TOKEN.balanceOf(address(TREASURY));

        if (treasuryTokenBalance == 0) return;

        amount = bound(amount, 1, treasuryTokenBalance);

        vm.prank(TIMELOCK_OWNER);

        TREASURY.transferERC20(address(SHADOW_TOKEN), address(this), amount);

        totalTokenWithdrawn += amount;
    }
}
