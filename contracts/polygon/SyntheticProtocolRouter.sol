// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./chainlink/RandomNumberConsumer.sol";
import "./implementations/SyntheticCollectionManager.sol";
import "./implementations/Jot.sol";
import "./implementations/JotPool.sol";
import "./implementations/SyntheticNFT.sol";
import "./auctions/AuctionsManager.sol";
import "./Structs.sol";
import "./governance/ProtocolParameters.sol";

contract SyntheticProtocolRouter is Ownable {
    using Counters for Counters.Counter;

    /**
     * @dev implementation addresses for proxies
     */
    address private _jot;
    address private _jotPool;
    address private _collectionManager;
    address private _syntheticNFT;
    address private _auctionManager;
    address private _protocol;
    address private _fundingTokenAddress;
    address private _randomConsumerAddress;
    address private _perpetualPoolLiteAddress;

    /**
     * @dev collections map.
     * collection address => collection data
     */
    mapping(address => SyntheticCollection) private _collections;

    /**
     * @dev get collection address from ID
     */
    mapping(uint256 => address) private _collectionIdToAddress;

    /**
     * @notice number of registered collections
     */
    Counters.Counter public protocolVaults;

    /**
     * @notice QuickSwap address
     */
    address public swapAddress;

    /**
     * Events
     */

    // a new Synthetic NFT collection manager is registered
    event CollectionManagerRegistered(
        uint256 collectionManagerID,
        address collectionManagerAddress,
        address jotAddress,
        address jotPoolAddress,
        address syntheticNFTAddress,
        address quickSwapAddress,
        address auctionAddress
    );

    event TokenRegistered(
        address collectionManagerAddress,
        uint256 collectionManagerID,
        uint256 syntheticTokenId
    );

    /**
     * Constructor
     */
    constructor(
        address swapAddress_,
        address jot_,
        address jotPool_,
        address collectionManager_,
        address syntheticNFT_,
        address auctionManager_,
        address protocol_,
        address fundingTokenAddress_,
        address randomConsumerAddress_,
        address perpetualPoolLiteAddress_
    ) {
        swapAddress = swapAddress_;
        _jot = jot_;
        _jotPool = jotPool_;
        _collectionManager = collectionManager_;
        _syntheticNFT = syntheticNFT_;
        _auctionManager = auctionManager_;
        _protocol = protocol_;
        _fundingTokenAddress = fundingTokenAddress_;
        _randomConsumerAddress = randomConsumerAddress_;
        _perpetualPoolLiteAddress = perpetualPoolLiteAddress_;
    }

    /**
     *  @notice register an NFT collection
     *  @param collection the address of the synthetic collection
     *  @param tokenId the token id
     *  @param supplyToKeep supply to keep
     *  @param priceFraction the price for a fraction
     *  @param originalName the original collection name
     *  @param originalSymbol the original collection symbol
     */
    function registerNFT(
        address collection,
        uint256 tokenId,
        uint256 supplyToKeep,
        uint256 priceFraction,
        string memory originalName,
        string memory originalSymbol
    ) public {
        address collectionAddress;
        uint256 collectionID = protocolVaults.current();
        // Checks whether a collection is registered or not
        // If not registered, then register it and increase the Vault counter
        if (!isSyntheticCollectionRegistered(collection)) {
            // deploys a minimal proxy contract from the jot contract implementation
            address jotAddress = Clones.clone(_jot);
            Jot(jotAddress).initialize(
                string(abi.encodePacked("Privi Jot ", originalName)),
                string(abi.encodePacked("JOT_", originalSymbol)),
                swapAddress,
                _fundingTokenAddress
            );

            // deploys a minimal proxy contract from the jotPool contract implementation
            address jotPoolAddress = Clones.clone(_jotPool);
            JotPool(jotPoolAddress).initialize(jotAddress);

            address syntheticNFTAddress = Clones.clone(_syntheticNFT);

            // deploys a minimal proxy contract from the collectionManager contract implementation
            collectionAddress = Clones.clone(_collectionManager);
            SyntheticCollectionManager collectionContract = SyntheticCollectionManager(collectionAddress);
            collectionContract.initialize(
                jotAddress,
                collection,
                syntheticNFTAddress,
                _auctionManager,
                _protocol,
                _fundingTokenAddress,
                jotPoolAddress
            );

            AuctionsManager(_auctionManager).grantRole(
                AuctionsManager(_auctionManager).COLLECTION_MANAGER(),
                collectionAddress
            );

            collectionContract.grantRole(collectionContract.RANDOM_ORACLE(), _randomConsumerAddress);
            Jot(jotAddress).grantRole(Jot(jotAddress).MINTER(), collectionAddress);

            // set the manager to allow control over the funds
            Jot(jotAddress).setManager(collectionAddress, jotPoolAddress);

            SyntheticNFT(syntheticNFTAddress).initialize(
                string(abi.encodePacked("Privi Synthetic ", originalName)),
                string(abi.encodePacked("pS_", originalSymbol)),
                collectionAddress
            );

            _collections[collection] = SyntheticCollection({
                collectionID: collectionID,
                collectionManagerAddress: collectionAddress,
                jotAddress: jotAddress,
                jotPoolAddress: jotPoolAddress,
                syntheticNFTAddress: syntheticNFTAddress,
                originalName: originalName,
                originalSymbol: originalSymbol
            });

            _collectionIdToAddress[collectionID] = collectionAddress;

            initPerpetualPoolLite(collectionID, originalName);

            // whitelist the new collection contract on the random number consumer
            RandomNumberConsumer(_randomConsumerAddress).whitelistCollection(collectionAddress);

            emit CollectionManagerRegistered(
                collectionID,
                collectionAddress,
                jotAddress,
                jotPoolAddress,
                syntheticNFTAddress,
                swapAddress,
                _auctionManager
            );

            protocolVaults.increment();

            //TODO: addSymbol with ”address” to the NFTPerpetualFutures
        } else {
            collectionAddress = _collections[collection].collectionManagerAddress;
        }

        SyntheticCollectionManager collectionManager = SyntheticCollectionManager(collectionAddress);

        collectionManager.register(tokenId, supplyToKeep, priceFraction);

        emit TokenRegistered(collectionAddress, collectionID, tokenId);
    }

    /**
     * @dev init Perpetual Pool Lite for a specific collection
     */
    
    function initPerpetualPoolLite(uint256 collectionID, string memory name) internal {
        ProtocolParameters protocol = ProtocolParameters(_protocol);
        address futuresOracleAddress = protocol.futuresOracleAddress();
        uint256 futuresMultiplier = protocol.futuresMultiplier();
        uint256 futuresFeeRatio = protocol.futuresFeeRatio();
        uint256 futuresFundingRateCoefficient = protocol.futuresFundingRateCoefficient();

        IPerpetualPoolLite futures = IPerpetualPoolLite(_perpetualPoolLiteAddress);

        futures.addSymbol(
            collectionID,
            name,
            futuresOracleAddress,
            futuresMultiplier,
            futuresFeeRatio,
            futuresFundingRateCoefficient
        );
    }

    /**
     * @notice checks whether a collection is registered or not
     */
    function isSyntheticCollectionRegistered(address collection) public view returns (bool) {
        return _collections[collection].collectionManagerAddress != address(0);
    }

    /**
     * @notice checks whether a Synthetic NFT has been created for a given NFT or not
     */
    function isSyntheticNFTCreated(address collection, uint256 tokenId) public view returns (bool) {
        // Collection must be registered first
        require(isSyntheticCollectionRegistered(collection), "Collection not registered");

        // connect to collection manager
        address collectionAddress = _collections[collection].collectionManagerAddress;
        address syntheticNFTAddress = SyntheticCollectionManager(collectionAddress).erc721address();

        // check whether a given id was minted or not
        return ISyntheticNFT(syntheticNFTAddress).exists(tokenId);
    }

    /**
     * @notice getter for Jot Address of a collection
     */
    function getJotsAddress(address collection) public view returns (address) {
        return _collections[collection].jotAddress;
    }

    /**
     * @notice getter for Jot Pool Address of a collection
     */
    function getJotPoolAddress(address collection) public view returns (address) {
        return _collections[collection].jotPoolAddress;
    }

    /**
     * @notice get collection manager address from collection address
     */
    function getCollectionManagerAddress(address collection) public view returns (address) {
        return _collections[collection].collectionManagerAddress;
    }

    /**
     * @notice get collection manager address from collection ID
     */
    function getCollectionManagerAddress(uint256 collectionID) public view returns (address) {
        address collectionAddress = _collectionIdToAddress[collectionID];
        return _collections[collectionAddress].collectionManagerAddress;
    }

    /**
     * @notice get collection ID from collection address
     */
    function getCollectionID(address collection) public view returns (uint256) {
        return _collections[collection].collectionID;
    }

    /**
     * @notice get collection address from collection ID
     */
    function getOriginalCollectionAddress(uint256 collectionID) public view returns (address) {
        return _collectionIdToAddress[collectionID];
    }
}
