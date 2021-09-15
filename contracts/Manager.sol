// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "./NFTFractions.sol";
import "./interfaces.sol";
import "hardhat/console.sol";

//import "https://github.com/priviprotocol/privi-financial-derivatives/blob/dev/contracts/pool/EverlastingOption.sol";

contract Manager {
    /* ******* */
    /* STRUCTS */
    /* ******* */

    /// @notice Information of tokens inside the vault
    struct structToken {
        address NFTOwner;
        address NFTFractionstokenAddress;
        uint256 syntheticNFTid;
        address optionAddress;
    }

    // Data of original NFT
    struct originalNFTData {
        address nftAddress;
        uint256 nftId;
    }

    // State variables
    /// @notice The current owner of the vault.
    address public owner;

    // Oracle address
    address private oracle;

    // Uniswap or Quickswap address
    // 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff is QuickSwap address (Polygon)
    // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D is UniSwap address (Ethereum Mainnet)
    address immutable swapAddress;

    // Address of the NFTFractions Factory
    address NFTFractionFactoryAddress;

    // Adress of the ERC721 Factory
    address ERC721FactoryAddress;

    // NFT address => NFT ID => Struct
    mapping(address => mapping(uint256 => structToken)) public tokenData;

    // ERC20 Address to original NFT data
    // ERC20 address => Struct
    mapping(address => originalNFTData) public erc20ToOriginalNFT;

    // synthetic NFT to original NFT data
    // NFT id => Struct
    mapping(uint256 => originalNFTData) public syntheticToOriginalNFT;

    // synthetic NFT address
    address public syntheticNftAddress;

    // governance data contract
    address public governanceAddress;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "Oracle: caller is not the oracle");
        _;
    }

    /**
     * @param _owner the owner of the Vault
     * @param _NFTFractionFactoryAddress the address of the NFTFractions factory
     * @param _ERC721FactoryAddress the address of the ERC721 factory
     * @param _swapAddress UniSwap (or clones) address
     * @param _name erc721 token name
     * @param _symbol erc721 token symbol
     */
    constructor(
        address _owner,
        address _NFTFractionFactoryAddress,
        address _ERC721FactoryAddress,
        address _swapAddress,
        address _governanceAddress,
        string memory _name,
        string memory _symbol
    ) {
        owner = _owner;
        NFTFractionFactoryAddress = _NFTFractionFactoryAddress;
        ERC721FactoryAddress = _ERC721FactoryAddress;
        swapAddress = _swapAddress;
        governanceAddress = _governanceAddress;

        IERC721TokenFactory ERC721TokenFactory = IERC721TokenFactory(address(_ERC721FactoryAddress));
        address _syntheticNftAddress = ERC721TokenFactory.deployERC721(
            address(this),
            _name,
            _symbol,
            _governanceAddress
        );
        syntheticNftAddress = _syntheticNftAddress;
    }

    /**
     * @notice Oracle-related function
     * @param nftAddress the address of the original NFT
     * @param nftId      the id of the original NFT
     * @param previousOrNewOwner the address of the previous (if received) or new  owner (sent)
     * @param received if true, the vault received a new NFT. if false, the vault transferred an NFT
     */
    function setNftInVault(
        address nftAddress,
        uint256 nftId,
        address previousOrNewOwner,
        bool received
    ) public onlyOracle {
        // do something
    }

    function isPreviousOwner(
        address nftAddress,
        uint256 nftId,
        address caller
    ) public view returns (bool) {
        return true;
    }

    function isNftInVault(address nftAddress, uint256 nftId) public view returns (bool) {
        return true;
    }

    // register NFT in the protocol
    function registerNFT(
        address nftAddress,
        uint256 nftId,
        string memory tokenURI,
        string[2] memory erc20TokenStringData,
        // explanation of string[2]
        //  string    memory name_ = data[0]
        // string    memory symbol_ = data[1]
        uint256[4] memory erc20tokenUintData,
        // explanation of uint[5]
        //uint256 decimals_         = erc20tokenUintData[0];
        //uint256 totalSupply_      = erc20tokenUintData[1];
        //uint256 _supplyToBeIssued = erc20tokenUintData[2];
        //uint256 initialPrice      = erc20tokenUintData[3];

        uint256 MinimumUnlockingDate
    ) public onlyOwner {
        // Verify that NFT is not already registered in protocol
        address NFTOwner = tokenData[nftAddress][nftId].NFTOwner;
        require(NFTOwner == address(0), "NFT is already registered in the protocol!");

        // Verify that the NFT is in the Vault
        bool _isNftInVault = isNftInVault(nftAddress, nftId);
        require(_isNftInVault == true, "Please transfer the NFT first!");

        // Verify that caller is previous owner of NFT
        bool _isPreviousOwner = isPreviousOwner(nftAddress, nftId, msg.sender);
        require(_isPreviousOwner == true, "You were not the previous owner!");

        // Save token data in mapping
        // NFTOwner is the original owner of the NFT (msg.sender)
        // ERC20tokenAddress is the address of the ERC20 Token (the fractions), still not generated, so address(0)
        // syntheticNFTid the id of the synthetic NFT
        // optionAddress the address of the option contract
        tokenData[nftAddress][nftId] = structToken(msg.sender, address(0), 0, address(0));
        generateSyntheticNFT(nftAddress, nftId, tokenURI, msg.sender);
        generateNFTFractionsToken(
            msg.sender,
            nftAddress,
            nftId,
            erc20TokenStringData[0],
            erc20TokenStringData[1],
            erc20tokenUintData[0],
            erc20tokenUintData[1],
            erc20tokenUintData[2],
            erc20tokenUintData[3],
            swapAddress
        );
    }

    function generateSyntheticNFT(
        address operator,
        uint256 tokenId,
        string memory tokenURI,
        address nftOwner
    ) internal {
        // Verify that synthetic NFT is not already generated
        uint256 syntheticNFTid = tokenData[operator][tokenId].syntheticNFTid;
        require(syntheticNFTid == 0, "Synthetic NFT already generated!");

        // Create Synthetic NFT
        SyntheticNFTInterface NFT = SyntheticNFTInterface(syntheticNftAddress);
        uint256 syntheticTokenId = NFT.safeMint(nftOwner, tokenURI);

        // save new token ID
        tokenData[operator][tokenId].syntheticNFTid = syntheticTokenId;
        syntheticToOriginalNFT[syntheticTokenId] = originalNFTData(operator, tokenId);
    }

    // Generate ERC20 Token
    function generateNFTFractionsToken(
        address beneficiary,
        address operator,
        uint256 tokenId,
        string memory name_,
        string memory symbol_,
        uint256 decimals_,
        uint256 totalSupply_,
        uint256 _supplyToBeIssued,
        uint256 initialPrice,
        address swapAddress
    ) public onlyOwner {
        // Verify that synthetic NFT has been generated
        uint256 syntheticNFTid = tokenData[operator][tokenId].syntheticNFTid;
        require(syntheticNFTid != 0, "Synthetic NFT not generated yet!");

        INFTFractionFactory erc20token = INFTFractionFactory(address(NFTFractionFactoryAddress));

        // Deploy NFTFractions Token
        address tokenAddress = erc20token.deployNFTFractions(
            beneficiary,
            address(this),
            name_,
            symbol_,
            decimals_,
            totalSupply_,
            _supplyToBeIssued,
            initialPrice,
            governanceAddress,
            swapAddress
        );

        tokenData[operator][tokenId].NFTFractionstokenAddress = tokenAddress;
        erc20ToOriginalNFT[tokenAddress] = originalNFTData(operator, tokenId);
    }

    /**
     * @dev get ERC20 token address for a given NFT
     * @param nftAddress the address of the ERC721 contract
     * @param tokenId the token ID
     */
    function getTokenAddress(address nftAddress, uint256 tokenId) public view returns (address) {
        return tokenData[nftAddress][tokenId].NFTFractionstokenAddress;
    }

    /**
     * @dev get synthetic token ID for a given original NFT
     * @param nftAddress the address of the ERC721 contract
     * @param tokenId the token ID
     */
    function getTokenId(address nftAddress, uint256 tokenId) public view returns (uint256) {
        return tokenData[nftAddress][tokenId].syntheticNFTid;
    }
}
