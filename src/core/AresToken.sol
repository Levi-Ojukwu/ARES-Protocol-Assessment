// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../interfaces/IERC20.sol";

contract AresToken is IERC20 {

    string  public name        = "ARES Token";
    string  public symbol      = "ARES";
    uint8   public decimals    = 18;
    uint256 public totalSupply;

    address public minter;

    mapping(address => uint256)                     public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    error NotMinter(address caller);
    error ZeroAddress();
    error InsufficientBalance(address account, uint256 have, uint256 need);
    error InsufficientAllowance(address spender, uint256 have, uint256 need);

    modifier onlyMinter() {
        if (msg.sender != minter) revert NotMinter(msg.sender);
        _;
    }

    constructor(address minter_) {
        if (minter_ == address(0)) revert ZeroAddress();
        minter = minter_;
    }

    function transfer(address to, uint256 amount) external returns (bool) {

        _transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {

        uint256 allowed = allowance[from][msg.sender];

        if (allowed < amount) revert InsufficientAllowance(msg.sender, allowed, amount);

        if (allowed != type(uint256).max) allowance[from][msg.sender] -= amount;

        _transfer(from, to, amount);

        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {

        if (spender == address(0)) revert ZeroAddress();

        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function mint(address to, uint256 amount) external onlyMinter {

        if (to == address(0)) revert ZeroAddress();

        totalSupply   += amount;

        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function setMinter(address newMinter) external onlyMinter {

        if (newMinter == address(0)) revert ZeroAddress();

        minter = newMinter;
    }

    function _transfer(address from, address to, uint256 amount) internal {

        if (to == address(0)) revert ZeroAddress();

        uint256 bal = balanceOf[from];

        if (bal < amount) revert InsufficientBalance(from, bal, amount);

        balanceOf[from] -= amount;

        balanceOf[to]   += amount;
        
        emit Transfer(from, to, amount);
    }
}