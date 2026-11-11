// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FalseReturnERC20 is ERC20 {
    constructor() ERC20("FalseReturn", "FR") {
        _mint(msg.sender, 1_000_000e18);
    }

    ///////////////////////////
    /// Function Overrides ///
    /////////////////////////

    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }
}
