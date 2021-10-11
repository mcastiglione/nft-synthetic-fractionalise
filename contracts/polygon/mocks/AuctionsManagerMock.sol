// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../auctions/AuctionsManager.sol";
import "hardhat/console.sol";

contract AuctionsManagerMock is AuctionsManager {
    constructor(address nftAuction_) AuctionsManager(nftAuction_) {}

    function reassignNFT(
        address collection_,
        uint256 nftId_,
        address newOwner_
    ) external override {
        SyntheticCollectionManager(collection_).reassignNFT(nftId_, newOwner_);
    }
}
