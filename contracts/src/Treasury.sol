// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DAO Treasury
 * @author 0xshdwfx
 * @notice Holds ETH and ERC-20 tokens and restricts withdrawals to the configured Timelock owner.
 * @dev The owner is set during deployment. Ownership transfer and renunciation are disabled.
 */
contract Treasury is Ownable {
    using SafeERC20 for IERC20;

    /////////////////
    /// Events //////
    /////////////////

    event ETHTransferred(address indexed recipient, uint256 amount);
    event ERC20Transferred(address indexed token, address indexed recipient, uint256 requestedAmount);

    /////////////////
    /// Errors //////
    /////////////////

    error Treasury__OwnershipChangeDisabled();
    error Treasury__InvalidRecipient();
    error Treasury__InvalidTransferAmount();
    error Treasury__TransferAmountExceedsTreasuryBalance();
    error Treasury__ETHTransferFailed();
    error Treasury__InvalidTokenAddress();
    error Treasury__TransferAmountExceedsTokenBalance();

    //////////////////////
    //// Constructor ////
    ////////////////////

    /**
     * @notice Deploys the Treasury with the supplied Timelock address as its owner.
     * @param timelockAddress The TimelockController authorised to withdraw Treasury assets.
     */
    constructor(address timelockAddress) Ownable(timelockAddress) {}

    /**
     * @notice Accepts ETH deposits sent without calldata from any address.
     */
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

    function transferERC20(address token, address recipient, uint256 amount) external onlyOwner {
        if (token == address(0)) revert Treasury__InvalidTokenAddress();

        if (recipient == address(0)) revert Treasury__InvalidRecipient();

        if (amount == 0) revert Treasury__InvalidTransferAmount();

        if (amount > IERC20(token).balanceOf(address(this))) revert Treasury__TransferAmountExceedsTokenBalance();

        IERC20(token).safeTransfer(recipient, amount);

        emit ERC20Transferred(token, recipient, amount);
    }
}
