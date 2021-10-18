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
import "./governance/FuturesProtocolParameters.sol";
import "../perpetual_futures/tokens/LTokenLite.sol";
import "../perpetual_futures/tokens/PTokenLite.sol";
import "../perpetual_futures/PerpetualPoolLite.sol";
import "../perpetual_futures/PoolInfo.sol";
import "./Interfaces.sol";

import {AuctionsManager} from "./auctions/AuctionsManager.sol";

contract SyntheticProtocolRouter is AccessControl, Ownable {
    using Counters for Counters.Counter;

    /**
     * @dev implementation addresses for proxies
     */
    address private _jot;
    address private _jotPool;
    address private _redemptionPool;
    address private _collectionManager;
    address private _syntheticNFT;
    address private _auctionManager;

    address private _protocol;
    address private _futuresProtocol;
    address private _randomConsumerAddress;
    address private _validatorAddress;

    address private _perpetualPoolLiteAddress;
    address private _lTokenLite;
    address private _pTokenLite;
    address private _poolInfo;

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
        address jotPairAddress,
        address syntheticNFTAddress,
        address quickSwapAddress,
        address auctionAddress,
        address lTokenLite_,
        address pTokenLite_,
        address perpetualPoolLiteAddress_,
        address poolInfo
    );

    event TokenRegistered(
        address collectionManagerAddress,
        uint256 collectionManagerID,
        uint256 syntheticTokenId
    );

    event TokenChanged(address collectionAddress, uint256 syntheticID, uint256 newID);

    constructor(
        address swapAddress_,
        address jot_,
        address jotPool_,
        address redemptionPoolAddress_,
        address collectionManager_,
        address syntheticNFT_,
        address auctionManager_,
        address randomConsumerAddress_,
        address validatorAddress_,
        FuturesParametersContracts memory futuresParameters,
        ProtocolParametersContracts memory protocolParameters
    ) {
        swapAddress = swapAddress_;
        _jot = jot_;
        _jotPool = jotPool_;
        _redemptionPool = redemptionPoolAddress_;
        _collectionManager = collectionManager_;
        _syntheticNFT = syntheticNFT_;
        _auctionManager = auctionManager_;
        _protocol = protocolParameters.fractionalizeProtocol;
        _futuresProtocol = protocolParameters.futuresProtocol;
        _randomConsumerAddress = randomConsumerAddress_;
        _validatorAddress = validatorAddress_;
        _lTokenLite = futuresParameters.lTokenLite_;
        _pTokenLite = futuresParameters.pTokenLite_;
        _perpetualPoolLiteAddress = futuresParameters.perpetualPoolLiteAddress_;
        _poolInfo = futuresParameters.poolInfo_;
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
        string memory originalSymbol,
        string memory metadata
    ) public {
        require(collection != address(0), "Invalid collection");

        address collectionAddress;
        // Checks whether a collection is registered or not
        // If not registered, then register it and increase the Vault counter
        if (!isSyntheticCollectionRegistered(collection)) {
            // deploys and initialize a Jot
            address jotAddress = _deployAndInitJot(
                string(abi.encodePacked("Privi Jot ", originalName)),
                string(abi.encodePacked("JOT_", originalSymbol))
            );

            // deploys and initialize a JotPool
            address jotPoolAddress = _deployAndInitJotPool(
                jotAddress,
                string(abi.encodePacked("Privi Jot ", originalName))
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
                string(abi.encodePacked("Privi Synthetic ", originalName)),
                string(abi.encodePacked("pS_", originalSymbol)),
                collectionAddress
            );

            // whitelist the new collection contract on the random number consumer and the validator
            RandomNumberConsumer(_randomConsumerAddress).whitelistCollection(collectionAddress);
            PolygonValidatorOracle(_validatorAddress).whitelistCollection(collectionAddress);

            // deploy and initialize future contracts
            FuturesParametersContracts memory futuresData = _deployFutures(
                originalName,
                originalSymbol,
                collection
            );

            SyntheticCollectionManager(collectionAddress).setPerpetualPoolLiteAddress(
                futuresData.perpetualPoolLiteAddress_
            );

            _collections[collection] = SyntheticCollection({
                collectionID: protocolVaults.current(),
                collectionManagerAddress: collectionAddress,
                jotAddress: jotAddress,
                jotPoolAddress: jotPoolAddress,
                jotPairAddress: Jot(jotAddress).uniswapV2Pair(),
                syntheticNFTAddress: syntheticNFTAddress,
                originalName: originalName,
                originalSymbol: originalSymbol,
                lTokenAddress: futuresData.lTokenLite_,
                pTokenAddress: futuresData.pTokenLite_,
                perpetualPoolLiteAddress: futuresData.perpetualPoolLiteAddress_,
                poolInfo: futuresData.poolInfo_
            });

            _collectionIdToAddress[protocolVaults.current()] = collectionAddress;

            emit CollectionManagerRegistered(
                protocolVaults.current(),
                collectionAddress,
                jotAddress,
                jotPoolAddress,
                Jot(jotAddress).uniswapV2Pair(),
                syntheticNFTAddress,
                swapAddress,
                _auctionManager,
                futuresData.lTokenLite_,
                futuresData.pTokenLite_,
                futuresData.perpetualPoolLiteAddress_,
                futuresData.poolInfo_
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
            metadata
        );

        emit TokenRegistered(collectionAddress, protocolVaults.current(), syntheticID);
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

    function _deployFutures(
        string memory originalName,
        string memory originalSymbol,
        address collection
    ) private returns (FuturesParametersContracts memory) {
        // Deploy futures
        address lTokenAddress = Clones.clone(_lTokenLite);
        LTokenLite(lTokenAddress).initialize(
            string(abi.encodePacked("Liquidity Futures ", originalName)),
            string(abi.encodePacked("LF_", originalSymbol))
        );

        address pTokenAddress = Clones.clone(_pTokenLite);
        PTokenLite(pTokenAddress).initialize(
            string(abi.encodePacked("Position Futures ", originalName)),
            string(abi.encodePacked("PF_", originalSymbol))
        );

        address nftFutureAddress = Clones.clone(_perpetualPoolLiteAddress);
        PerpetualPoolLite(nftFutureAddress).initialize(
            [
                ProtocolParameters(_protocol).fundingTokenAddress(),
                lTokenAddress,
                pTokenAddress,
                _jotPool, // TODO: change by liquidator address
                _jotPool,
                collection
            ]
        );

        address poolInfo = Clones.clone(_poolInfo);
        PoolInfo(poolInfo).initialize(nftFutureAddress);

        LTokenLite(lTokenAddress).setPool(nftFutureAddress);
        PTokenLite(pTokenAddress).setPool(nftFutureAddress);

        return FuturesParametersContracts(lTokenAddress, pTokenAddress, nftFutureAddress, poolInfo);
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
        return SyntheticCollectionManager(collectionManager).isVerified(tokenId);
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

    function getCollectionlTokenAddress(address collection) public view returns (address) {
        return _collections[collection].lTokenAddress;
    }

    function getCollectionpTokenAddress(address collection) public view returns (address) {
        return _collections[collection].pTokenAddress;
    }

    function getCollectionPerpetualPoolAddress(address collection) public view returns (address) {
        return _collections[collection].perpetualPoolLiteAddress;
    }

    function getCollectionUniswapPair(address collection) public view returns (address) {
        return _collections[collection].jotPairAddress;
    }
}
