// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./interfaces.sol";
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

    /**
     * @notice address of the original collection
     */
    address public _originalCollectionAddress;

    /**
    * @dev ERC20 totalSupply (governance) parameter
    * TODO: get from governance
     */
    uint256 private jotSupply;

    /**
    * @notice jot Address for this collection
     */
    address public jotAddress;

    struct JotsData {
        address nftOwner;
        uint256 ownerSupply;
        uint256 sellingSupply;
        uint256 soldSupply;
        uint256 liquiditySupply;
        uint256 liquiditySold;
        uint256 fractionPrices;    
    }

    /**
    * @notice Jot data for each token
     */
    mapping(uint256 => JotsData) public  _jots;

    IUniswapV2Router02 public uniswapV2Router;

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
        owner = msg.sender;
    }

    function updateJotAddress(address jotAddress_) public onlyOwner {
        jotAddress = jotAddress_;
    }

    /**
     * @notice This method calls chainlink oracle and
     * verifies if the NFT has been locked on NFTVaultManager. In addition
     * gets the metadata of the NFT
     */
    function verifyNFT (uint256 tokenId) public view returns (bool) {
        // TODO: call chainlink Oracle
        return true;
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
    * @notice Get the owner of the NFT
     */
    function getNFTOwner(uint256 tokenId) private view returns (address) {
        //TODO: get owner from Oracle
        return address(0);
    }

    /**
     * @notice returns the Quickswap pool address
     */
    function poolAddress() public view returns (address) {
        //TODO: check if pool is initiated 
        return Jot(jotAddress).uniswapV2Pair();
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
        return _jots[tokenId].ownerSupply != 0;
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
    * (e) Register liquiditySupply = (JotSupply-supplyToKeep)/2.
    * (f) Register liquiditySold = 0
    *
     */
    function register(uint256 tokenId, uint256 supplyToKeep, uint256 priceFraction) public onlyOwner {

        _tokenCounter.increment();
        string memory metadata = getNFTMetadata(tokenId);
        generateSyntheticNFT(msg.sender, tokenId, metadata);

        Jot jot = Jot(jotAddress);

        jot.safeMint(address(this), jotSupply);

        uint256 sellingSupply = (jotSupply-supplyToKeep)/2;
        uint256 liquiditySupply = (jotSupply-supplyToKeep)/2;
        address nftOwner = getNFTOwner(tokenId);

        JotsData memory data = JotsData(
            nftOwner,
            supplyToKeep, 
            sellingSupply, 
            0, 
            liquiditySupply, 
            0, 
            priceFraction
        );

        _jots[tokenId] = data;
    }

    /**
    * @notice allows the caller to buy Jots
     */
    function BuyJotTokens(uint256 tokenId) payable public{

        // Calculate amount to be bought
        uint256 amount = msg.value / _jots[tokenId].fractionPrices;
        require(amount > 0, "You need to send some ether");

        // Calculate amount left
        uint256 amountLeft = _jots[tokenId].sellingSupply - _jots[tokenId].soldSupply;

        // If amount left is lesser than buying amount
        // then buying amount = amount left
        
        if (amountLeft < amount) {
            amount = amountLeft;
        }

        // Can't sell zero tokens
        require(amount != 0, "No tokens left!");

        // Transfer Jots
        Jot(jotAddress).transferFrom(address(this), msg.sender, amount);
        
        //Increase sold supply (amount in token) and liquidity sold (amount in ether)
        _jots[tokenId].soldSupply += amount;
        _jots[tokenId].liquiditySold += msg.value;

        //If all jots have been sold, then add liquidity 
        if (amount == amountLeft) {
            addLiquidityToPool(tokenId);
        }
    }

    /**
     * @notice increase selling supply for a given NFT
     * caller must be the owner of the NFT
     */

    function increaseSellingSupply(uint256 tokenId, uint256 amount) public {
        require(msg.sender == _jots[tokenId].nftOwner, "You are not the owner of the NFT!");
        require(_jots[tokenId].ownerSupply >= amount, "You do not have enough tokens left");
        _jots[tokenId].ownerSupply -= amount;
        _jots[tokenId].sellingSupply += amount/2;
        _jots[tokenId].liquiditySupply += amount/2;
    }

    /**
     * @notice decrease selling supply for a given NFT
     * caller must be the owner of the NFT
     */
    function decreaseSellingSupply(uint256 tokenId, uint256 amount) public {
        require(msg.sender == _jots[tokenId].nftOwner, "You are not the owner of the NFT!");
        require(_jots[tokenId].liquiditySupply >= amount/2, "You do not have enough liquidity left");
        require(_jots[tokenId].sellingSupply >= amount/2, "You do not have enough selling supply left");

        _jots[tokenId].ownerSupply += amount;
        _jots[tokenId].sellingSupply -= amount/2;
        _jots[tokenId].liquiditySupply -= amount/2;

    }

    /**
     * @notice update the price of a fraction for a given NFT
     * caller must be the owner
     */
    function updatePriceFraction(uint256 tokenId, uint256 newFractionPrice) public {
        require(msg.sender == _jots[tokenId].nftOwner, "You are not the owner of the NFT!");
        _jots[tokenId].fractionPrices = newFractionPrice;
    }


    /**
     * @notice add available liquidity for a given token to UniSwap pool
     */
    function addLiquidityToPool(uint256 tokenId) public {
        uint256 liquiditySupply = _jots[tokenId].liquiditySupply;
        uint256 liquiditySold = _jots[tokenId].liquiditySold;

        // approve token transfer to cover all possible scenarios
        Jot(jotAddress).approve(address(uniswapV2Router), liquiditySupply);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: liquiditySold}(
            jotAddress,
            liquiditySupply,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner,
            block.timestamp
        );
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
