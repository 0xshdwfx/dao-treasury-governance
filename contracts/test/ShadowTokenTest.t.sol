// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Console.sol";
import {ShadowToken} from "../src/ShadowToken.sol";

contract ShadowTokenTest is Test {
    ShadowToken public shadowToken;

    address public deployer = makeAddr("deployer");
    address public recipient = makeAddr("recipient");

    uint256 private constant INITIAL_SUPPLY = 1_000_000e18;
    uint8 private constant TOKEN_DECIMALS = 18;
    uint256 private constant TRANSFER_AMOUNT = 100;

    function setUp() public {
        vm.prank(deployer);
        shadowToken = new ShadowToken();
    }

    function test_TokenMetadataMatchesSpecification() public view {
        assertEq(shadowToken.name(), "Shadow", "token name should be Shadow");
        assertEq(shadowToken.symbol(), "SHDW", "token symbol should be SHDW");
    }

    function test_InitialSupplyIsFullyAllocatedToDeployer() public view {
        assertEq(shadowToken.totalSupply(), INITIAL_SUPPLY, "total supply should equal initial supply");
        assertEq(shadowToken.balanceOf(deployer), INITIAL_SUPPLY, "deployer should receive the initial supply");
    }

    function test_TokenDecimalsAreEighteen() public view {
        assertEq(shadowToken.decimals(), TOKEN_DECIMALS, "token decimals should equal 18");
    }

    function test_PermitNonceStartsAtZeroForDeployer() public view {
        assertEq(shadowToken.nonces(deployer), 0, "deployer permit nonce should start at zero");
    }

    function test_TokenTransferDecreasesDeployerBalanceAndIncreasesRecipientBalance() public {
        vm.startPrank(deployer);

        uint256 recipientBalanceBeforeTransfer = shadowToken.balanceOf(recipient);
        uint256 deployerBalanceBeforeTransfer = shadowToken.balanceOf(deployer);

        shadowToken.transfer(recipient, TRANSFER_AMOUNT);

        uint256 recipientBalanceAfterTransfer = shadowToken.balanceOf(recipient);
        uint256 deployerBalanceAfterTransfer = shadowToken.balanceOf(deployer);

        vm.stopPrank();

        assertEq(
            recipientBalanceAfterTransfer,
            recipientBalanceBeforeTransfer + TRANSFER_AMOUNT,
            "recipient balance should increase by transfer amount"
        );
        assertEq(
            deployerBalanceAfterTransfer,
            deployerBalanceBeforeTransfer - TRANSFER_AMOUNT,
            "deployer balance should decrease by transfer amount"
        );
    }
}
