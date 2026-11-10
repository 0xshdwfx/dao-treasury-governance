// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

error RejectingETHRecipient__RecipientRejectedETH();

contract RejectingETHRecipient {
    receive() external payable {
        revert RejectingETHRecipient__RecipientRejectedETH();
    }
}
