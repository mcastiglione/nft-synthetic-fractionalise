// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

struct TokenData {
    uint256 originalTokenID;
    uint256 ownerSupply;
    uint256 sellingSupply;
    uint256 soldSupply;
    uint256 liquiditySupply;
    uint256 liquiditySold;
    uint256 fractionPrices;
    uint256 lastFlipTime;
    uint256 liquidityToken;
    bool verified;
    bool verifying;

}

struct Flip {
    uint256 tokenId;
    uint64 prediction;
    address player;
}
