// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract InterestRateModel {
    uint public baseRate = 5;  // 5% base interest rate
    uint public multiplier = 10; // 10% increase based on utilization rate

    function getBorrowRate(uint totalBorrows, uint totalReserves) external view returns (uint) {
        uint utilizationRate = (totalBorrows * 1e18) / (totalBorrows + totalReserves);
        return baseRate + utilizationRate * multiplier / 1e18;
    }
}
