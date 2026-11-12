// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NoReturnERC20 is ERC20 {
    constructor() ERC20("NoReturn", "NR") {
        _mint(msg.sender, 1_000_000e18);
    }

    ///////////////////////////
    /// Function Overrides ///
    /////////////////////////

    function transfer(address to, uint256 value) public override returns (bool) {
        super.transfer(to, value);

        assembly {
            return(0, 0)
        }
    }
}
