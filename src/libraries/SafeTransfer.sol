// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library SafeTransfer {
    error ETHTransferFailed(address recipient, uint256 amount);

    function safeTransferETH(address recipient, uint256 amount) internal {

        (bool ok,) = recipient.call{value: amount}("");
        
        if (!ok) revert ETHTransferFailed(recipient, amount);
    }
}