// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./chainlink/RandomNumberConsumer.sol";
import "./chainlink/PolygonValidatorOracle.sol";
import "./implementations/SyntheticCollectionManager.sol";
import "./implementations/Jot.sol";
import "./implementations/JotPool.sol";
import "./implementations/RedemptionPool.sol";
import "./implementations/SyntheticNFT.sol";
import "./Structs.sol";
import "./governance/ProtocolParameters.sol";
import "./Interfaces.sol";
import "./implementations/Enums.sol";

import {AuctionsManager} from "./auctions/AuctionsManager.sol";

contract SyntheticProtocolRouter is AccessControl, Ownable {
    using Counters for Counters.Counter;

    address private _jot;
    address private _jotPool;
    address private _redemptionPool;
    address private _collectionManager;
    address private _syntheticNFT;
    address private _auctionManager;

    address private _protocol;
    address private _randomConsumerAddress;
    address private _validatorAddress;

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

    // a new Synthetic NFT collection manager is registered
    event CollectionManagerRegistered(
        uint256 collectionManagerID,
        address collectionManagerAddress,
        address jotAddress,
        address jotPoolAddress,
        address redemptionPoolAddress,
        address jotPairAddress,
        address syntheticNFTAddress,
        address quickSwapAddress,
        address auctionAddress
    );

    event TokenRegistered(
        address collectionManagerAddress,
        uint256 syntheticTokenId
    );

    event TokenChanged(
        address collectionAddress, 
        uint256 syntheticID, 
        uint256 newID
        );

    constructor(
        /* array composed by:
            swapAddress, 
            jot.address, 
            jotPool.address, 
            redemptionPool.address,
            collectionManager.address,
            syntheticNFT.address,
            auctionsManager.address,
            randomConsumer.address,
            validator.address,
         */
        address[9] memory addresses_,
        address protocol_
    ) {
        swapAddress = addresses_[0];
        _jot = addresses_[1];
        _jotPool = addresses_[2];
        _redemptionPool = addresses_[3];
        _collectionManager = addresses_[4];
        _syntheticNFT = addresses_[5];
        _auctionManager = addresses_[6];
        _randomConsumerAddress = addresses_[7];
        _validatorAddress = addresses_[8];
        _protocol = protocol_;
    }

    /**
     *  @notice register an NFT collection
     *  @param collection the address of the synthetic collection
     *  @param tokenId the token id
     *  @param supplyToKeep supply to keep
     *  @param registrationMetadata the metadata for the registration
     */
    function registerNFT(
        address collection,
        uint256 tokenId,
        uint256 supplyToKeep,
        uint256 priceFraction,
        RegistrationMetadata calldata registrationMetadata
    ) external {
        require(priceFraction > 0, "Price fraction can't be zero");
        require(collection != address(0), "Invalid collection");
        require(supplyToKeep <= ProtocolConstants.JOT_SUPPLY, "Invalid supply to keep");

        address collectionAddress;
        // Checks whether a collection is registered or not
        // If not registered, then register it and increase the Vault counter
        if (!isSyntheticCollectionRegistered(collection)) {
            // deploys and initialize a Jot
            address jotAddress = _deployAndInitJot(
                string(abi.encodePacked("Privi Jot ", registrationMetadata.originalName)),
                string(abi.encodePacked("JOT_", registrationMetadata.originalSymbol))
            );

            // deploys and initialize a JotPool
            address jotPoolAddress = _deployAndInitJotPool(
                jotAddress,
                string(abi.encodePacked("Privi Jot ", registrationMetadata.originalName))
            );

            // deploys a SyntheticNFT
            address syntheticNFTAddress = Clones.clone(_syntheticNFT);

            // deploys a RedemptionPool
            address redemptionPoolAddress = Clones.clone(_redemptionPool);

            // deploys and init a SyntheticCollectionManager
            collectionAddress = _deployAndInitSyntheticCollection(
                jotAddress,
                jotPoolAddress,
                redemptionPoolAddress,
                syntheticNFTAddress,
                collection
            );

            // initializes the RedemptionPool
            RedemptionPool(redemptionPoolAddress).initialize(
                jotAddress,
                ProtocolParameters(_protocol).fundingTokenAddress(),
                collectionAddress
            );

            // assigns the roles to the deployed contracts
            _assignRoles(jotAddress, jotPoolAddress, collectionAddress);

            // initializes the SyntheticNFT
            SyntheticNFT(syntheticNFTAddress).initialize(
                string(abi.encodePacked("Privi Synthetic ", registrationMetadata.originalName)),
                string(abi.encodePacked("pS_", registrationMetadata.originalSymbol)),
                collectionAddress
            );

            // whitelist the new collection contract on the random number consumer and the validator
            RandomNumberConsumer(_randomConsumerAddress).whitelistCollection(collectionAddress);
            PolygonValidatorOracle(_validatorAddress).whitelistCollection(collectionAddress);

            _collections[collection] = SyntheticCollection({
                collectionID: protocolVaults.current(),
                collectionManagerAddress: collectionAddress,
                jotAddress: jotAddress,
                jotPoolAddress: jotPoolAddress,
                redemptionPoolAddress: redemptionPoolAddress,
                jotPairAddress: Jot(jotAddress).uniswapV2Pair(),
                syntheticNFTAddress: syntheticNFTAddress,
                originalName: registrationMetadata.originalName,
                originalSymbol: registrationMetadata.originalSymbol
            });

            _collectionIdToAddress[protocolVaults.current()] = collectionAddress;

            emit CollectionManagerRegistered(
                protocolVaults.current(),
                collectionAddress,
                jotAddress,
                jotPoolAddress,
                redemptionPoolAddress,
                Jot(jotAddress).uniswapV2Pair(),
                syntheticNFTAddress,
                swapAddress,
                _auctionManager
            );

            protocolVaults.increment();
        } else {
            collectionAddress = _collections[collection].collectionManagerAddress;
        }

        SyntheticCollectionManager collectionManager = SyntheticCollectionManager(collectionAddress);

        uint256 syntheticID = collectionManager.register(
            tokenId,
            supplyToKeep,
            priceFraction,
            msg.sender,
            registrationMetadata.metadata
        );

        emit TokenRegistered(collectionAddress, syntheticID);
    }

    function _deployAndInitJot(string memory originalName_, string memory originalSymbol_)
        private
        returns (address jotAddress)
    {
        // deploys a minimal proxy contract from the jot contract implementation
        jotAddress = Clones.clone(_jot);
        Jot(jotAddress).initialize(
            string(abi.encodePacked("Privi Jot ", originalName_)),
            string(abi.encodePacked("JOT_", originalSymbol_)),
            swapAddress,
            ProtocolParameters(_protocol).fundingTokenAddress()
        );
    }

    function _deployAndInitJotPool(address jotAddress_, string memory originalName_)
        private
        returns (address jotPoolAddress)
    {
        // deploys a minimal proxy contract from the jotPool contract implementation
        jotPoolAddress = Clones.clone(_jotPool);
        JotPool(jotPoolAddress).initialize(
            jotAddress_,
            ProtocolParameters(_protocol).fundingTokenAddress(),
            string(abi.encodePacked("Privi JotPool ", originalName_)),
            string(abi.encodePacked(" ", originalName_))
        );
    }

    function _deployAndInitSyntheticCollection(
        address jotAddress_,
        address jotPoolAddress_,
        address redemptionPoolAddress_,
        address syntheticNFTAddress_,
        address collection_
    ) private returns (address collectionAddress) {
        // deploys a minimal proxy contract from the collectionManager contract implementation
        collectionAddress = Clones.clone(_collectionManager);

        SyntheticCollectionManager(collectionAddress).initialize(
            jotAddress_,
            collection_,
            syntheticNFTAddress_,
            _auctionManager,
            _protocol,
            jotPoolAddress_,
            redemptionPoolAddress_,
            swapAddress
        );
    }

    function _assignRoles(
        address jotAddress_,
        address jotPoolAddress_,
        address collectionAddress_
    ) private {
        AuctionsManager(_auctionManager).grantRole(
            AuctionsManager(_auctionManager).COLLECTION_MANAGER(),
            collectionAddress_
        );

        // Done this way because of stack limitations
        SyntheticCollectionManager(collectionAddress_).grantRole(
            SyntheticCollectionManager(collectionAddress_).RANDOM_ORACLE(),
            _randomConsumerAddress
        );

        SyntheticCollectionManager(collectionAddress_).grantRole(
            SyntheticCollectionManager(collectionAddress_).VALIDATOR_ORACLE(),
            _validatorAddress
        );

        Jot(jotAddress_).grantRole(Jot(jotAddress_).MINTER(), collectionAddress_);

        // set the manager to allow control over the funds
        Jot(jotAddress_).setManager(collectionAddress_, jotPoolAddress_);
    }

    /**
     * @notice change an NFT for another one
     */
    function changeNFT(
        address collection,
        uint256 syntheticId,
        uint256 newOriginalId,
        string memory metadata
    ) public {
        address collectionManager = getCollectionManagerAddress(collection);
        SyntheticCollectionManager manager = SyntheticCollectionManager(collectionManager);
        manager.change(syntheticId, newOriginalId, metadata, msg.sender);

        emit TokenChanged(collection, syntheticId, newOriginalId);
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
     * @notice checks whether a Synthetic has been verified or not
     */
    function isNFTVerified(address collection, uint256 tokenId) public view returns (bool) {
        require(isSyntheticNFTCreated(collection, tokenId), "NFT not registered");
        address collectionManager = getCollectionManagerAddress(collection);
        //return SyntheticCollectionManager(collectionManager).isVerified(tokenId);

        (,,,,,,,State verified) = SyntheticCollectionManager(collectionManager).tokens(tokenId);

        return (verified == State.VERIFIED);
    }

    /**
     * @notice verify a synthetic NFT
     */
    function verifyNFT(address collection, uint256 tokenId) public {
        address collectionManager = getCollectionManagerAddress(collection);
        SyntheticCollectionManager(collectionManager).verify(tokenId);
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
    function getCollectionManagerAddressFromId(uint256 collectionID) public view returns (address) {
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

    function getCollectionUniswapPair(address collection) public view returns (address) {
        return _collections[collection].jotPairAddress;
    }
}
