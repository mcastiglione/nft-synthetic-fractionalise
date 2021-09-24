// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

struct TokenData {
    uint256 originalID;
    uint256 ownerSupply;
    uint256 sellingSupply;
    uint256 soldSupply;
    uint256 liquiditySupply;
    uint256 liquiditySold;
    uint256 fractionPrices;
    uint256 lastFlipTime;
    bool verified;
}

struct Flip {
    uint256 tokenId;
    uint256 prediction;
}
