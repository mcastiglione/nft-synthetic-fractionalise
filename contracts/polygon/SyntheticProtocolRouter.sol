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
import "./implementations/SyntheticNFT.sol";
import "./auctions/AuctionsManager.sol";
import "./Structs.sol";
import "./governance/ProtocolParameters.sol";
import "./governance/FuturesProtocolParameters.sol";
import "../perpetual_futures/tokens/LTokenLite.sol";
import "../perpetual_futures/tokens/PTokenLite.sol";
import "../perpetual_futures/PerpetualPoolLite.sol";
import "./Interfaces.sol";

contract SyntheticProtocolRouter is AccessControl, Ownable {
    using Counters for Counters.Counter;

    bytes32 public constant ORACLE = keccak256("ORACLE");

    /**
     * @dev implementation addresses for proxies
     */
    address private _jot;
    address private _jotPool;
    address private _collectionManager;
    address private _syntheticNFT;
    address private _auctionManager;

    address private _protocol;
    address private _futuresProtocol;
    address private _fundingTokenAddress;
    address private _randomConsumerAddress;
    address private _validatorAddress;

    address private _perpetualPoolLiteAddress;
    address private _lTokenLite;
    address private _pTokenLite;

    address public oracleAddress;
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
        address perpetualPoolLiteAddress_
    );

    event TokenRegistered(
        address collectionManagerAddress,
        uint256 collectionManagerID,
        uint256 syntheticTokenId
    );

    event TokenChanged(address collectionAddress, uint256 syntheticID, uint256 previousID, uint256 newID);

    constructor(
        address swapAddress_,
        address jot_,
        address jotPool_,
        address collectionManager_,
        address syntheticNFT_,
        address auctionManager_,
        address fundingTokenAddress_,
        address randomConsumerAddress_,
        address validatorAddress_,
        address oracleAddress_,
        FuturesParametersContracts memory futuresParameters,
        ProtocolParametersContracts memory protocolParameters
        ) {
        swapAddress = swapAddress_;
        _jot = jot_;
        _jotPool = jotPool_;
        _collectionManager = collectionManager_;
        _syntheticNFT = syntheticNFT_;
        _auctionManager = auctionManager_;
        _protocol = protocolParameters.fractionalizeProtocol;
        _futuresProtocol = protocolParameters.futuresProtocol;
        _fundingTokenAddress = fundingTokenAddress_;
        _randomConsumerAddress = randomConsumerAddress_;
        _validatorAddress = validatorAddress_;
        _lTokenLite = futuresParameters.lTokenLite_;
        _pTokenLite = futuresParameters.pTokenLite_;
        _perpetualPoolLiteAddress = futuresParameters.perpetualPoolLiteAddress_;
        oracleAddress = oracleAddress_;
        _setupRole(ORACLE, oracleAddress_);
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
        require(collection != address(0), "Invalid collection");

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
            SyntheticCollectionManager(collectionAddress).initialize(
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

            // Done this way because of stack limitations
            SyntheticCollectionManager(collectionAddress).grantRole(
                SyntheticCollectionManager(collectionAddress).RANDOM_ORACLE(), 
                _randomConsumerAddress
            );
            
            SyntheticCollectionManager(collectionAddress).grantRole(
                SyntheticCollectionManager(collectionAddress).VALIDATOR_ORACLE(), 
                _validatorAddress
            );

            Jot(jotAddress).grantRole(Jot(jotAddress).MINTER(), collectionAddress);

            // set the manager to allow control over the funds
            Jot(jotAddress).setManager(collectionAddress, jotPoolAddress);

            SyntheticNFT(syntheticNFTAddress).initialize(
                string(abi.encodePacked("Privi Synthetic ", originalName)),
                string(abi.encodePacked("pS_", originalSymbol)),
                collectionAddress
            );

            // whitelist the new collection contract on the random number consumer and the validator
            RandomNumberConsumer(_randomConsumerAddress).whitelistCollection(collectionAddress);
            PolygonValidatorOracle(_validatorAddress).whitelistCollection(collectionAddress);

            FuturesParametersContracts memory futuresParameters;
            futuresParameters.lTokenLite_ = _lTokenLite;
            futuresParameters.pTokenLite_ = _pTokenLite;
            futuresParameters.perpetualPoolLiteAddress_ = _perpetualPoolLiteAddress;

            FuturesParametersContracts memory futuresData = deployFutures(
                originalName,
                originalSymbol,
                collection,
                futuresParameters
            );

            _collections[collection] = SyntheticCollection({
                collectionID: collectionID,
                collectionManagerAddress: collectionAddress,
                jotAddress: jotAddress,
                jotPoolAddress: jotPoolAddress,
                jotPairAddress: Jot(jotAddress).uniswapV2Pair(),
                syntheticNFTAddress: syntheticNFTAddress,
                originalName: originalName,
                originalSymbol: originalSymbol,
                lTokenAddress: futuresData.lTokenLite_,
                pTokenAddress: futuresData.pTokenLite_,
                perpetualPoolLiteAddress: futuresData.perpetualPoolLiteAddress_
            });

            _collectionIdToAddress[collectionID] = collectionAddress;

            emit CollectionManagerRegistered(
                collectionID,
                collectionAddress,
                jotAddress,
                jotPoolAddress,
                Jot(jotAddress).uniswapV2Pair(),
                syntheticNFTAddress,
                swapAddress, 
                _auctionManager,
                futuresData.lTokenLite_,
                futuresData.pTokenLite_,
                futuresData.perpetualPoolLiteAddress_
            );

            protocolVaults.increment();

        } else {
            collectionAddress = _collections[collection].collectionManagerAddress;
        }

        SyntheticCollectionManager collectionManager = SyntheticCollectionManager(collectionAddress);

        uint256 syntheticID = collectionManager.register(tokenId, supplyToKeep, priceFraction, msg.sender);

        emit TokenRegistered(collectionAddress, collectionID, syntheticID);
    }

    function deployFutures(
        string memory originalName,
        string memory originalSymbol,
        address collection,
        FuturesParametersContracts memory futuresParameters
    ) private returns (FuturesParametersContracts memory ) {
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
        PerpetualPoolLite(nftFutureAddress).initialize([
            _fundingTokenAddress,
            lTokenAddress,
            pTokenAddress,
            _jotPool, // TODO: change by liquidator address
            _jotPool,
            collection
        ]);

        LTokenLite(lTokenAddress).setPool(nftFutureAddress);
        PTokenLite(pTokenAddress).setPool(nftFutureAddress);

        return FuturesParametersContracts(lTokenAddress, pTokenAddress, nftFutureAddress);
    }

    /**
     * @notice change an NFT for another one
     */
    function changeNFT(
        address collection,
        uint256 syntheticID,
        uint256 newOriginalTokenID
    ) public {
        address collectionManager = getCollectionManagerAddress(collection);
        SyntheticCollectionManager manager = SyntheticCollectionManager(collectionManager);
        uint256 originalTokenID = manager.getOriginalID(syntheticID);
        manager.change(syntheticID, newOriginalTokenID, msg.sender);

        emit TokenChanged(collection, syntheticID, originalTokenID, newOriginalTokenID);
    }

    /**
     * @dev init Perpetual Pool Lite for a specific collection
     */

    // function initPerpetualPoolLite(uint256 collectionID, string memory name) internal view {
    //     FuturesProtocolParameters futuresProtocol = FuturesProtocolParameters(_futuresProtocol);
    //     address futuresOracleAddress = futuresProtocol.futuresOracleAddress();
    // }

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
    function verifyNFT(address collection, uint256 tokenId) public onlyRole(ORACLE) {
        require(isSyntheticNFTCreated(collection, tokenId), "NFT not registered");
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
