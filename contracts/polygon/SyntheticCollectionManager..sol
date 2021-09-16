// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./SyntheticERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SyntheticCollectionManager is ERC721 {
    
    // token id => bool
    // false, an nft has not been registered
    // true, an nft has been registered
    mapping(uint => bool) public _tokens;

    // URIs mapping
    // token id => metadata
	mapping(uint => string) private _tokenMetadata;

    // token id => erc20 address
    mapping(uint => address) private _jots;

    /**
     * @notice deployed synthetic NFT address
     */
    address public _originalCollectionAddress;

    constructor(
        address originalCollectionAddress_, 
        string memory name_, 
        string memory symbol_
    ) ERC721(
        name_, 
        symbol_
    ) {
        _originalCollectionAddress = originalCollectionAddress_;
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
        return _tokenMetadata[tokenId];
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
        return true;
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
	function generateSyntheticNFT(address to, uint tokenId, string memory metadata) public onlyOwner {
        require(isSyntheticNFTCreated(tokenId) == false, "Synthetic NFT already generated!");
		_safeMint(to, tokenId);
        tokens[tokenId] = true;
        tokenMetadata[tokenId] = metadata;
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

    function RegisterNFT(uint256 tokenId, uint256 supplyToKeep, uint256 priceFraction) public {
        
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
        tokens[tokenId] = false;
        tokenMetadata[tokenId] = "";
	}

}