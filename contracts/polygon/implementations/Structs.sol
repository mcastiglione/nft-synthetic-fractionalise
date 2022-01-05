// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./Enums.sol";

struct TokenData {
    uint256 originalTokenID;
    uint256 ownerSupply;
    uint256 sellingSupply;
    uint256 soldSupply;
    uint256 liquiditySold;
    uint256 fractionPrices;
    uint256 lastFlipTime;
    State state;
}

struct Flip {
    uint256 tokenId;
    uint64 prediction;
    address player;
}

struct ChangeNonce {
    uint256 nonce;
    uint256 newTokenId;
    address owner;
}
