// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../src/Treasury.sol";
import {TreasuryHandler} from "./handlers/TreasuryHandler.sol";
import {ShadowToken} from "../../src/ShadowToken.sol";

contract TreasuryInvariantTest is Test {
    Treasury public treasury;
    TreasuryHandler public handler;
    ShadowToken public shadowToken;

    address public timelockOwner = makeAddr("timelockOwner");

    function setUp() public {
        treasury = new Treasury(timelockOwner);
        shadowToken = new ShadowToken();
        handler = new TreasuryHandler(treasury, timelockOwner, shadowToken);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = TreasuryHandler.depositEth.selector;
        selectors[1] = TreasuryHandler.withdrawEth.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));

        bool success = shadowToken.transfer(address(handler), shadowToken.totalSupply());
        assertTrue(success, "Shadow token transfer to handler should succeed");
    }

    function invariant_TreasuryEthBalanceMatchesTrackedDepositsMinusWithdrawals() public view {
        assertEq(
            address(treasury).balance,
            handler.totalEthDeposited() - handler.totalEthWithdrawn(),
            "Treasury ETH balance must equal total deposited minus total withdrawn"
        );
    }
}
