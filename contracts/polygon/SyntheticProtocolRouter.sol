// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./SyntheticCollectionManager.sol";
import "./Jot.sol";
import "./JotStaking.sol";
import "./SyntheticERC721.sol";

contract SyntheticProtocolRouter {

    struct SyntheticCollection {
        address CollectionManager;
        address SyntheticERC721Address;
        address JotAddress;
        address JotStakingAddress;
    }

    mapping(address => SyntheticCollection) collections;
    mapping(address => mapping(uint256 => bool)) private fractions;

    using Counters for Counters.Counter;
	Counters.Counter public protocolVaults;

    constructor() {}

    function isSyntheticCollectionRegistered(address collection) public view returns (bool) {
        return collections[collection].SyntheticERC721Address != address(0);
    }

    function isSyntheticNFTCreated(address collection, uint256 tokenid) public view returns (bool) {
        return fractions[collection][tokenid];
    }

    function registerNFT(address collection, uint256 tokenid, uint256 supplyToKeep, uint256 priceFraction) public onlyOwner {
        
        SyntheticCollectionManager collectionmanager; 
        
        if (!isSyntheticCollectionRegistered(collection)) {
            SyntheticERC721 erc721 = new SyntheticERC721();
            collectionmanager = new SyntheticCollectionManager(erc721.address);
            Jot jot = new Jot();
            JotStaking jotstaking = new JotStaking();
        } else {
            collectionmanager = SyntheticCollectionManager(collections[collection].CollectionManager);
        }

        protocolVaults.increment();
    }
}