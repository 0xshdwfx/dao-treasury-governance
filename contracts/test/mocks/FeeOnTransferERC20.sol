// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FeeOnTransferERC20 is ERC20 {
    address public immutable feeRecipient;

    error InvalidFeeRecipient();

    constructor(address _feeRecipient) ERC20("FeeOnTransfer", "FOT") {
        if (_feeRecipient == address(0)) revert InvalidFeeRecipient();

        feeRecipient = _feeRecipient;

        _mint(msg.sender, 1_000_000e18);
    }

    ///////////////////////////
    /// Function Overrides ///
    /////////////////////////

    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        uint256 feeAmount = value / 100;
        uint256 netAmount = value - feeAmount;

        if (feeAmount > 0) {
            super._update(from, feeRecipient, feeAmount);
        }

        super._update(from, to, netAmount);
    }
}
