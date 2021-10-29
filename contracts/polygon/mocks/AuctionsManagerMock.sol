// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../auctions/AuctionsManager.sol";
import "hardhat/console.sol";

contract AuctionsManagerMock is AuctionsManager {
    // solhint-disable-next-line
    constructor() AuctionsManager() {}

    function reassignNFT(
        address collection_,
        uint256 nftId_,
        address newOwner_
    ) external override {
        ISyntheticCollectionManager(collection_).reassignNFT(nftId_, newOwner_);
    }
}
