// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PriceOracle {
    mapping(address => uint) public assetPrices;

    function setPrice(address asset, uint price) external {
        assetPrices[asset] = price;
    }

    function getPrice(address asset) external view returns (uint) {
        return assetPrices[asset];
    }
}
