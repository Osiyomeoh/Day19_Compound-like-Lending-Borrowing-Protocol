// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CToken {
    IERC20 public underlying;
    uint public totalSupply; // Total supply of cTokens
    uint public totalBorrows; // Total borrowed amount
    uint public totalReserves; // Total reserves
    uint public exchangeRate; // Current exchange rate of cTokens to underlying tokens
    uint public lastAccrualBlock; // Block number of last interest accrual
    uint public reserveFactor = 10; // 10% reserve

    bool private locked; // Manual reentrancy guard

    mapping(address => uint) public balances; // Mapping of user balances
    mapping(address => uint) public borrowBalances; // Mapping of borrow balances

    constructor(address _underlying) {
        underlying = IERC20(_underlying);
        exchangeRate = 1e18; // Initial exchange rate
        lastAccrualBlock = block.number;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrancy not allowed");
        locked = true;
        _;
        locked = false;
    }

    modifier updateInterest() {
        accrueInterest();
        _;
    }

    function accrueInterest() internal {
        uint blockDelta = block.number - lastAccrualBlock;
        if (blockDelta > 0) {
            // Ensure interest calculation is based on non-zero borrows
            uint interestAccrued = (totalBorrows * blockDelta) / 10000; // Simplified interest accrual
            totalBorrows += interestAccrued;
            totalReserves += (interestAccrued * reserveFactor) / 100;

            // Avoid division by zero when calculating exchangeRate
            if (totalSupply > 0) {
                exchangeRate = (totalSupply + totalBorrows - totalReserves) * 1e18 / totalSupply;
            }

            lastAccrualBlock = block.number;
        }
    }

    function mint(uint amount) external nonReentrant updateInterest {
        require(underlying.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // Calculate the cToken amount based on the exchange rate
        uint cTokenAmount = (amount * 1e18) / exchangeRate;
        balances[msg.sender] += cTokenAmount;
        totalSupply += cTokenAmount;
    }

    function redeem(uint cTokenAmount) external nonReentrant updateInterest {
        require(balances[msg.sender] >= cTokenAmount, "Insufficient balance");
        
        // Calculate the underlying amount to redeem
        uint underlyingAmount = (cTokenAmount * exchangeRate) / 1e18;
        balances[msg.sender] -= cTokenAmount;
        totalSupply -= cTokenAmount;

        require(underlying.transfer(msg.sender, underlyingAmount), "Transfer failed");
    }

    function borrow(uint amount) external nonReentrant updateInterest {
        borrowBalances[msg.sender] += amount;
        totalBorrows += amount;
        require(underlying.transfer(msg.sender, amount), "Transfer failed");
    }

    function repayBorrow(uint amount) external nonReentrant updateInterest {
        require(borrowBalances[msg.sender] >= amount, "Repay more than debt");
        require(underlying.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        borrowBalances[msg.sender] -= amount;
        totalBorrows -= amount;
    }

    function balanceOf(address account) external view returns (uint) {
        return balances[account];
    }
}
