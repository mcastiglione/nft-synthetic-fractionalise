// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./SyntheticCollectionManager.sol";
import "./Jot.sol";
import "./JotStaking.sol";
import "./SyntheticERC721.sol";

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
     * @dev collections struct
     */
    struct SyntheticCollection {
        address CollectionManager;
        address SyntheticERC721Address;
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

    constructor() {}

    /**
     * @notice checks whether a collection is registered or not
     */
    function isSyntheticCollectionRegistered(
        address collection
    ) public view returns (bool) {
        return collections[collection].CollectionManager != address(0);
    }

    /**
     * @notice checks whether a Synthetic NFT has been created for a given NFT or not
     */
    function isSyntheticNFTCreated(
        address collection, 
        uint256 tokenid
    ) public view returns (bool) {
        return false;
    }

    /**
     *  @notice register an NFT
     *  @param collection the address of the collection
     *  @param tokenid the token id 
     *  @param supplyToKeep supply to keep 
     *  @param priceFraction the price for a fraction
     */
    function registerNFT(
        address collection, 
        uint256 tokenid, 
        uint256 supplyToKeep, 
        uint256 priceFraction
    ) public onlyOwner {
        
        SyntheticCollectionManager collectionmanager; 
        
        // Checks whether a collection is registered or not
        // If not registered, then register it and increase the Vault counter
        if (!isSyntheticCollectionRegistered(collection)) {
            SyntheticERC721 erc721 = new SyntheticERC721();
            collectionmanager = new SyntheticCollectionManager(address(erc721));
            Jot jot = new Jot();
            JotStaking jotstaking = new JotStaking();

            collections[collection] = SyntheticCollection(
                address(collectionmanager), 
                address(erc721), 
                address(jot), 
                address(jotstaking)
            );

            protocolVaults.increment();
        } else {
            collectionmanager = SyntheticCollectionManager(collections[collection].CollectionManager);
        }

        // TODO: try to register a new NFT
    }
}