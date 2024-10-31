// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CToken.sol";

contract Comptroller {
    mapping(address => CToken) public markets; // Maps each asset to its CToken market
    mapping(address => mapping(address => uint)) public userCollaterals; // Maps user to asset collateral amounts
    mapping(address => address[]) public userAssets; // Tracks assets each user has supplied as collateral

    uint public collateralFactor = 50; // 50% collateral factor

    function addMarket(address asset, address cToken) external {
        markets[asset] = CToken(cToken);
    }

    function supplyCollateral(address asset, uint amount) external {
        require(address(markets[asset]) != address(0), "Unsupported market");
        CToken cToken = markets[asset];
        require(cToken.underlying().transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // If the asset is new for the user, add it to their list
        if (userCollaterals[msg.sender][asset] == 0) {
            userAssets[msg.sender].push(asset);
        }

        // Update the collateral amount
        userCollaterals[msg.sender][asset] += amount;
    }

    function checkCollateral(address borrower, uint borrowAmount) external view returns (bool) {
        uint totalCollateral = 0;
        uint requiredCollateral = (borrowAmount * 1e18) / collateralFactor;

        // Calculate total collateral across all assets for the borrower
        address[] memory assets = userAssets[borrower];
        for (uint i = 0; i < assets.length; i++) {
            address asset = assets[i];
            CToken cToken = markets[asset];

            // Calculate the collateral for this asset
            uint assetCollateral = (userCollaterals[borrower][asset] * cToken.exchangeRate()) / 1e18;
            totalCollateral += assetCollateral;
        }

        return totalCollateral >= requiredCollateral;
    }
}
