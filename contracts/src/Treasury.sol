// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Treasury is Ownable {
    using SafeERC20 for IERC20;

    /////////////////
    /// Events //////
    /////////////////

    event ETHTransferred(address indexed recipient, uint256 amount);

    /////////////////
    /// Errors //////
    /////////////////

    error Treasury__OwnershipChangeDisabled();
    error Treasury__InvalidRecipient();
    error Treasury__InvalidTransferAmount();
    error Treasury__TransferAmountExceedsTreasuryBalance();
    error Treasury__ETHTransferFailed();

    //////////////////////
    //// Constructor ////
    ////////////////////

    constructor(address timelockAddress) Ownable(timelockAddress) {}

    receive() external payable {}

    ///////////////////////////
    /// Function Overrides ///
    //////////////////////////

    function transferOwnership(address) public view override onlyOwner {
        revert Treasury__OwnershipChangeDisabled();
    }

    function renounceOwnership() public view override onlyOwner {
        revert Treasury__OwnershipChangeDisabled();
    }

    ///////////////////
    /// Functions /////
    ///////////////////

    function transferETH(address payable recipient, uint256 amount) external onlyOwner {
        if (recipient == address(0)) revert Treasury__InvalidRecipient();

        if (amount == 0) revert Treasury__InvalidTransferAmount();

        if (amount > address(this).balance) revert Treasury__TransferAmountExceedsTreasuryBalance();

        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert Treasury__ETHTransferFailed();

        emit ETHTransferred(recipient, amount);
    }
}
