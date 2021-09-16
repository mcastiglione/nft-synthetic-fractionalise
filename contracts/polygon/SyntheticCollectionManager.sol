// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Jot.sol";
import "./SyntheticProtocolRouter.sol";

contract SyntheticCollectionManager is ERC721 {

    
	using Counters for Counters.Counter;
    
    /**
     * @notice Number of tokens in Vault
     */ 
	Counters.Counter public _tokenCounter;

    /**
     * @notice The current owner of the vault.
     */
    address public owner;

    /**
     * @notice the address of the Protocol Router
     */
    address public _syntheticProtocolRouterAddress;

    // token id => bool
    // false, an nft has not been registered
    // true, an nft has been registered
    mapping(uint => bool) public _tokens;

    // URIs mapping
    // token id => metadata
	mapping(uint => string) private _tokenMetadata;

    // token id => metadata
    // token supply to keep
	mapping(uint => uint256) private _tokenSupplyToKeep;

    // token id => metadata
    // token fraction price
    mapping(uint => uint256) private _tokenFractionPrice;

    // token id => erc20 address
    mapping(uint => address) private _jots;

    /**
     * @notice deployed synthetic NFT address
     */
    address public _originalCollectionAddress;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    constructor(
        address originalCollectionAddress_, 
        string memory name_, 
        string memory symbol_
    ) ERC721(
        name_, 
        symbol_
    ) {
        _originalCollectionAddress = originalCollectionAddress_;
        _syntheticProtocolRouterAddress = msg.sender;
    }

    /**
     * @notice This method calls chainlink oracle and
     * verifies if the NFT has been locked on NFTVaultManager. In addition
     * gets the metadata of the NFT
     */
    function verifyNFT (uint256 tokenId) public view returns (string memory) {
        // Work in progress
        return "";
    }

    /**
     * @notice Gets the metadata
     * of the NFT. This should have been registered first by verifyNFT.
     */
    function getNFTMetadata(uint256 tokenId) private view returns (string memory) {
        //TODO: get metadata from Oracle
        return "";
    }

    /**
     * @notice returns a boolean based on if the pool on Quickswap
     * for the collection ”address” is registered.
     */
    function isPoolInitiated() public view returns (bool) {
        //TODO: check if pool is initiated 
        return true;
    }

    /**
     * @notice public function. Checks if an NFT has
     * been already minted.
     */
    function isSyntheticNFTCreated(uint256 tokenId) public view returns (bool) {
        return _tokens[tokenId];
    }

    /**
     * @notice public function. Checks if an NFT has
     * been already fractionalised.
     */
    function isSyntheticNFTFractionalised(uint256 tokenId) public view returns (bool) {
        return _jots[tokenId] != address(0);
    }

    /**
     * @notice Checks isSyntheticNFTCreated(address, id) is False. 
     * Then it mints a new NFT with: ”to”, ”id” and ”metadata”
     */
	function generateSyntheticNFT(address to, uint tokenId, string memory metadata) private {
        require(isSyntheticNFTCreated(tokenId) == false, "Synthetic NFT already generated!");
		_safeMint(to, tokenId);
        _tokens[tokenId] = true;
        _tokenMetadata[tokenId] = metadata;
	}


    /**
    * @notice First
    * it updates counter syntheticID++. Then:
    * • generateSyntheticNFT(address, id)
    * • Interacts with JOT contract for that address and:
    * (a) Mints JotSupply (governance parameter)
    * (b) Register ownerSupply (DO NOT SEND HIM/HER)
    * (c) Register sellingSupply = (JotSupply-supplyToKeep)/2
    * (d) Register soldSupply = 0
    * (e) Register liquididitySupply = (JotSupply-supplyToKeep)/2.
    * (f) Register liquiditySold = 0
    *
     */
    function RegisterNFT(uint256 tokenId, uint256 supplyToKeep, uint256 priceFraction) public {

        _tokenCounter.increment();
        string memory metadata = getNFTMetadata(tokenId);
        generateSyntheticNFT(msg.sender, tokenId, metadata);

        SyntheticProtocolRouter router = SyntheticProtocolRouter(_syntheticProtocolRouterAddress);

        address jotAddress = router.getJotStakingAddress(_originalCollectionAddress);

        Jot jot = Jot(jotAddress);

        //TODO: interact with Jot 
        // (a) Mints JotSupply (governance parameter)
        // (b) Register ownerSupply (DO NOT SEND HIM/HER)
        // (c) Register sellingSupply = (JotSupply-supplyToKeep)/2
        // (d) Register soldSupply = 0
        // (e) Register liquididitySupply = (JotSupply-supplyToKeep)/2.
        // (f) Register liquiditySold = 0
    }

    /**
     * @notice First, checks isSyntheticNFTFractionalised(address, id) is False. 
     * Then it mints a new NFT with: ”id”
     * and with metadata = getNFTMetadata(address,id).
     */
    function generateJots(uint tokenId) public onlyOwner {
        require(!isSyntheticNFTFractionalised(tokenId));
        //TODO: integrate with real Jot
        Jot jot = new Jot();
        _jots[tokenId] = address(jot);
    }

    function BuyJotTokens(uint256 tokenId, uint256 amount) public {
        
    }

    function increaseSellingSupply(uint256 tokenId, uint256 amount) public onlyOwner {
        
    }

    function decreaseSellingSupply(uint256 tokenId, uint256 amount) public onlyOwner {
        
    }

    function updatePriceFraction(uint256 tokenId, uint256 newFractionPrice) public onlyOwner {
        
    }

    function AddLiquidityToPool(uint256 tokenId) public {
        
    }

    function isAllowedToFlip(uint256 tokenId) public view {
        
    }

    function flipJot(uint256 tokenId, uint256 prediction) public {
        
    }

    /**
     * @dev burn a token
     */
    function safeBurn(uint tokenId) public onlyOwner {
		_burn(tokenId);
        _tokens[tokenId] = false;
        _tokenMetadata[tokenId] = "";
        _tokenCounter.decrement();
	}

}