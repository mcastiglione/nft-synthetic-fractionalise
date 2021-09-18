// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./implementations/SyntheticCollectionManager.sol";
import "./implementations/Jot.sol";
import "./implementations/JotPool.sol";
import "./Structs.sol";

contract SyntheticProtocolRouter is Ownable {
    using Counters for Counters.Counter;

    /**
     * @dev implementation addresses for proxies
     */
    address private _jot;
    address private _jotPool;
    address private _collectionManager;
    address private _auctionManager;

    /**
     * @notice number of registered collections
     */
    Counters.Counter public protocolVaults;

    /**
     * @notice QuickSwap address
     */
    address public swapAddress;

    /**
     * @dev collections map.
     * collection address => collection data
     */
    mapping(address => SyntheticCollection) private collections;

    constructor(
        address _swapAddress,
        address jot_,
        address jotPool_,
        address collectionManager_,
        address auctionManager_
    ) {
        swapAddress = _swapAddress;
        _jot = jot_;
        _jotPool = jotPool_;
        _collectionManager = collectionManager_;
        _auctionManager = auctionManager_;
    }

    /**
     *  @notice register an NFT
     *  @param collection the address of the synthetic collection
     *  @param tokenId the token id
     *  @param supplyToKeep supply to keep
     *  @param priceFraction the price for a fraction
     *  @param originalName the original collection name
     *  @param originalSymbol the original collection symbol
     *  @param originalSymbol the original address of the collection
     */
    function registerNFT(
        address collection,
        uint256 tokenId,
        uint256 supplyToKeep,
        uint256 priceFraction,
        string memory originalName,
        string memory originalSymbol,
        address originalAddress
    ) public onlyOwner {
        address collectionAddress;

        // Checks whether a collection is registered or not
        // If not registered, then register it and increase the Vault counter
        if (!isSyntheticCollectionRegistered(collection)) {
            // deploys a minimal proxy contract from the jot contract implementation
            address jotAddress = Clones.clone(_jot);
            Jot(jotAddress).initialize(
                string(abi.encodePacked("Privi Jot ", originalName)),
                string(abi.encodePacked("Jot", originalName)),
                swapAddress
            );

            // deploys a minimal proxy contract from the jotPool contract implementation
            address jotPoolAddress = Clones.clone(_jotPool);
            JotPool(jotPoolAddress).initialize(jotAddress);

            // deploys a minimal proxy contract from the collectionManager contract implementation
            collectionAddress = Clones.clone(_collectionManager);
            SyntheticCollectionManager(collectionAddress).initialize(
                string(abi.encodePacked("Synthetic ", originalName)),
                string(abi.encodePacked("s", originalSymbol)),
                jotAddress,
                originalAddress,
                _auctionManager
            );

            collections[collection] = SyntheticCollection({
                collectionManagerAddress: collectionAddress,
                jotAddress: jotAddress,
                jotStakingAddress: jotPoolAddress
            });

            protocolVaults.increment();

            //TODO: addSymbol with ”address” to the NFTPerpetualFutures
        } else {
            collectionAddress = collections[collection].collectionManagerAddress;
        }

        SyntheticCollectionManager collectionManager = SyntheticCollectionManager(collectionAddress);

        collectionManager.register(tokenId, supplyToKeep, priceFraction);
    }

    /**
     * @notice checks whether a collection is registered or not
     */
    function isSyntheticCollectionRegistered(address collection) public view returns (bool) {
        return collections[collection].collectionManagerAddress != address(0);
    }

    /**
     * @notice checks whether a Synthetic NFT has been created for a given NFT or not
     */
    function isSyntheticNFTCreated(address collection, uint256 tokenId) public view returns (bool) {
        // Collection must be registered first
        require(isSyntheticCollectionRegistered(collection), "Collection not registered");

        // connect to collection manager
        address collectionAddress = collections[collection].collectionManagerAddress;
        SyntheticCollectionManager collectionManager = SyntheticCollectionManager(collectionAddress);

        // check whether a given id was minted or not
        return collectionManager._tokens(tokenId);
    }

    /**
     * @notice getter for Jot Address of a collection
     */
    function getJotsAddress(address collection) public view returns (address) {
        return collections[collection].jotAddress;
    }

    /**
     * @notice getter for Jot Staking Address of a collection
     */
    function getJotStakingAddress(address collection) public view returns (address) {
        return collections[collection].jotStakingAddress;
    }

    /**
     * @notice getter for Collection Manager Address of a collection
     */
    function getCollectionManagerAddress(address collection) public view returns (address) {
        return collections[collection].collectionManagerAddress;
    }
}
