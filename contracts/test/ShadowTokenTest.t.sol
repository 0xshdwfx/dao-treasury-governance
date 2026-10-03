// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ShadowToken} from "../src/ShadowToken.sol";

contract ShadowTokenTest is Test {
    ShadowToken public shadowToken;

    address public deployer = makeAddr("deployer");

    function setUp() public {
        vm.prank(deployer);
        shadowToken = new ShadowToken();
    }

    function test_NameAndSymbol() public {
        assertEq(shadowToken.name(), "Shadow");
        assertEq(shadowToken.symbol(), "SHDW");
    }
}
