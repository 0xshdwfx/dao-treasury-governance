// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RevertingERC20 is ERC20 {
    constructor() ERC20("RevertingERC20", "RVT") {
        _mint(msg.sender, 1_000_000e18);
    }

    error TransferInvalid();

    ///////////////////////////
    /// Function Overrides ///
    /////////////////////////

    function transfer(address, uint256) public pure override returns (bool) {
        revert TransferInvalid();
    }
}
