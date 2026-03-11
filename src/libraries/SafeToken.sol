// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../interfaces/IERC20.sol";

library SafeToken {

    error TransferFailed(address token, address to, uint256 amount);
    error TransferFromFailed(address token, address from, address to, uint256 amount);
    function safeTransfer(address token, address to, uint256 amount) internal {

        bool ok = IERC20(token).transfer(to, amount);

        if (!ok) revert TransferFailed(token, to, amount);
    }

    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {

        bool ok = IERC20(token).transferFrom(from, to, amount);

        if (!ok) revert TransferFromFailed(token, from, to, amount);
    }
}