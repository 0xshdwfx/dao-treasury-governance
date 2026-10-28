// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Treasury is Ownable {
    using SafeERC20 for IERC20;

    /////////////////
    /// Errors //////
    /////////////////

    error Treasury__OwnershipChangeDisabled();

    //////////////////////
    //// Constructor ////
    ////////////////////

    constructor(address timelockAddress) Ownable(timelockAddress) {}

    receive() external payable {}

    ///////////////////////////
    /// Function Overrides ///
    //////////////////////////

    function transferOwnership(address) public override onlyOwner {
        revert Treasury__OwnershipChangeDisabled();
    }

    function renounceOwnership() public override onlyOwner {
        revert Treasury__OwnershipChangeDisabled();
    }
}
