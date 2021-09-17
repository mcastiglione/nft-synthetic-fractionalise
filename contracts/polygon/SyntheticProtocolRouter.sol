// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./SyntheticCollectionManager.sol";
import "./Jot.sol";
import "./JotPool.sol";

contract SyntheticProtocolRouter {

    using Counters for Counters.Counter;

    /**
     * @notice number of registered collections
     */
	Counters.Counter public protocolVaults;

    /**
     * @notice The current owner of the vault.
     */
    address public owner;

    /**
     * @notice QuickSwap address
     */
    address public swapAddress;

    /**
     * @dev collections struct
     */
    struct SyntheticCollection {
        address CollectionManagerAddress;
        address JotAddress;
        address JotStakingAddress;
    }

    /**
     * @dev collections map. 
     * collection address => collection data
     */
    mapping(address => SyntheticCollection) private collections;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    constructor(address _swapAddress) {
        swapAddress = _swapAddress;
    }

    /**
     * @notice checks whether a collection is registered or not
     */
    function isSyntheticCollectionRegistered(
        address collection
    ) public view returns (bool) {
        return collections[collection].CollectionManagerAddress != address(0);
    }

    /**
     * @notice checks whether a Synthetic NFT has been created for a given NFT or not
     */
    function isSyntheticNFTCreated(
        address collection, 
        uint256 tokenId
    ) public view returns (bool) {
        // Collection must be registered first
        require(isSyntheticCollectionRegistered(collection), "Collection not registered");
        
        // connect to collection manager
        address collectionAddress = collections[collection].CollectionManagerAddress;
        SyntheticCollectionManager collectionManager = SyntheticCollectionManager(collectionAddress);

        // check whether a given id was minted or not
        return collectionManager._tokens(tokenId);
    }

    /**
     *  @notice register an NFT
     *  @param collection the address of the collection
     *  @param tokenId the token id 
     *  @param supplyToKeep supply to keep 
     *  @param priceFraction the price for a fraction
     */
    function registerNFT(
        address collection, 
        uint256 tokenId, 
        uint256 supplyToKeep, 
        uint256 priceFraction,
        string memory name_, 
        string memory symbol_
    ) public onlyOwner {
        
        SyntheticCollectionManager collectionmanager; 
        
        // Checks whether a collection is registered or not
        // If not registered, then register it and increase the Vault counter
        if (!isSyntheticCollectionRegistered(collection)) {
            collectionmanager = new SyntheticCollectionManager(collection, name_, symbol_);
            Jot jot = new Jot(address(collectionmanager), swapAddress);
            collectionmanager.updateJotAddress(address(jot));
            //TODO: JotPool is Initializable, add Clones.clone()
            JotPool jotPool = new JotPool();

            collections[collection] = SyntheticCollection(
                address(collectionmanager), 
                address(jot), 
                address(jotPool)
            );

            protocolVaults.increment();

            //TODO: addSymbol with ”address” to the NFTPerpetualFutures
        } else {

            address collectionManagerAddress = collections[collection].CollectionManagerAddress;
            collectionmanager = SyntheticCollectionManager(collectionManagerAddress);
        }

        collectionmanager.register(tokenId, supplyToKeep, priceFraction);
        
    }


    /** 
     * @notice getter for Jot Address of a collection
     */
    function getJotsAddress(address collection) public view returns (address)  {
        return collections[collection].JotAddress;
    }

    /** 
     * @notice getter for Jot Staking Address of a collection
     */
    function getJotStakingAddress(address collection) public view returns (address) {
        return collections[collection].JotStakingAddress;
    }

    /** 
     * @notice getter for Collection Manager Address of a collection
     */
    function getCollectionManagerAddress(address collection) public view returns (address) {
        return collections[collection].CollectionManagerAddress;
    }

}