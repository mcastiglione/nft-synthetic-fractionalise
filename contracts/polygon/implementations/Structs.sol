// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

struct JotsData {
    address nftOwner;
    uint256 ownerSupply;
    uint256 sellingSupply;
    uint256 soldSupply;
    uint256 liquiditySupply;
    uint256 liquiditySold;
    uint256 fractionPrices;
}
