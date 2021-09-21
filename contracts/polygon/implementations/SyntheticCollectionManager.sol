// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../extensions/IERC20ManagedAccounts.sol";
import "../auctions/AuctionsManager.sol";
import "../chainlink/RandomNumberConsumer.sol";
import "../SyntheticProtocolRouter.sol";
import "../Interfaces.sol";
import "../governance/ProtocolParameters.sol";
import "./Jot.sol";
import "./Structs.sol";

contract SyntheticCollectionManager is AccessControl, Initializable {
    using SafeERC20 for IERC20;

    bytes32 public constant ROUTER = keccak256("ROUTER");
    bytes32 public constant AUCTION_MANAGER = keccak256("AUCTION_MANAGER");
    bytes32 public constant RANDOM_ORACLE = keccak256("RANDOM_ORACLE");

    using Counters for Counters.Counter;
    Counters.Counter public _tokenCounter;

    address private immutable _randomConsumerAddress;
    address private _auctionsManagerAddress;

    /**
     * @dev mapping the request id with the flip input data
     */
    mapping(bytes32 => Flip) private _flips;

    /**
     * @notice the address of the Protocol Router
     */
    address public _syntheticProtocolRouterAddress;

    ProtocolParameters public protocol;

    // token id => bool
    // false, an nft has not been registered
    // true, an nft has been registered
    mapping(uint256 => bool) public _tokens;

    // URIs mapping
    // token id => metadata
    mapping(uint256 => string) private _tokenMetadata;

    /**
     * @notice address of the original collection
     */
    address public _originalCollectionAddress;

    /**
     * @dev ERC20 totalSupply (governance) parameter
     * TODO: get from governance
     */
    uint256 private jotsSupply;

    /**
     * @notice jot Address for this collection
     */
    address public jotAddress;

    /**
     * @notice funding token address
     */
    address public fundingTokenAddress;

    /**
     * @notice Jot data for each token
     */
    mapping(uint256 => JotsData) public _jots;

    mapping(uint256 => bool) public lockedNFTs;

    /**
     * @notice Synthetic NFT Address  for this collection
     */
    address public erc721address;

    IUniswapV2Router02 public uniswapV2Router;

    address public jotPool;

    event CoinFlipped(
        bytes32 indexed requestId,
        address indexed player,
        uint256 indexed tokenId,
        uint256 prediction
    );
    event FlipProcessed(
        bytes32 indexed requestId,
        uint256 indexed tokenId,
        uint256 prediction,
        uint256 randomResult
    );

    constructor(address randomConsumerAddress) {
        _randomConsumerAddress = randomConsumerAddress;
    }

    function initialize(
        address _jotAddress,
        address originalCollectionAddress_,
        address _erc721address,
        address auctionManagerAddress,
        address protocol_,
        address fundingTokenAddress_,
        address jotPool_
    ) external initializer {
        jotAddress = _jotAddress;
        erc721address = _erc721address;
        _originalCollectionAddress = originalCollectionAddress_;
        _syntheticProtocolRouterAddress = msg.sender;
        _auctionsManagerAddress = auctionManagerAddress;
        protocol = ProtocolParameters(protocol_);
        jotPool = jotPool_;

        jotsSupply = protocol.jotsSupply();
        fundingTokenAddress = fundingTokenAddress_;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ROUTER, msg.sender);
        _setupRole(AUCTION_MANAGER, auctionManagerAddress);
    }

    /**
     * @dev we need to pass the jobSupply here to work well even when the governance
     *      changes this protocol parameter in the middle of the auction
     */
    function reassignNFT(
        uint256 nftId_,
        address newOwner_,
        uint256 jotsSupply_
    ) external onlyRole(AUCTION_MANAGER) {
        JotsData storage data = _jots[nftId_];

        // the auction could only be started if ownerSupply is 0
        assert(data.ownerSupply == 0);

        // TODO: implement this logic

        // data.ownerSupply = jotsSupply_;
        // data.sellingSupply = 0;
        // data.soldSupply = 0;
        // data.liquiditySupply = 0;
        // data.liquiditySold = 0;
        // data.fractionPrices = 0;
    }

    /**
     * @notice This method calls chainlink oracle and
     * verifies if the NFT has been locked on NFTVaultManager. In addition
     * gets the metadata of the NFT
     */
    function verifyNFT(uint256 tokenId) public view returns (bool) {
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
    function getSyntheticNFTOwner(uint256 tokenId) private view returns (address) {
        //TODO: get owner from Oracle
        return IERC721(erc721address).ownerOf(tokenId);
    }

    /**
     * @notice returns the Quickswap pool address
     */
    function poolAddress() public view returns (address) {
        //TODO: check if pool is initiated
        return IJot(jotAddress).uniswapV2Pair();
    }

    /**
     * @notice public function. Checks if an NFT has
     * been already minted.
     */
    function isSyntheticNFTCreated(uint256 tokenId) public view returns (bool) {
        return ISyntheticNFT(erc721address).exists(tokenId);
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
    function generateSyntheticNFT(
        address to,
        uint256 tokenId,
        string memory metadata
    ) private {
        require(isSyntheticNFTCreated(tokenId) == false, "Synthetic NFT already generated!");
        ISyntheticNFT(erc721address).safeMint(to, tokenId, metadata);
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
    function register(
        uint256 tokenId,
        uint256 supplyToKeep,
        uint256 priceFraction
    ) public onlyRole(ROUTER) {
        _tokenCounter.increment();
        string memory metadata = getNFTMetadata(tokenId);
        generateSyntheticNFT(msg.sender, tokenId, metadata);

        Jot(jotAddress).mint(address(this), jotsSupply);

        uint256 sellingSupply = (jotsSupply - supplyToKeep) / 2;
        uint256 liquiditySupply = (jotsSupply - supplyToKeep) / 2;

        JotsData memory data = JotsData(supplyToKeep, sellingSupply, 0, liquiditySupply, 0, priceFraction, 0);

        _jots[tokenId] = data;
    }

    /**
     * @notice allows the caller to buy jots using the Funding token
     */
    function buyJotTokens(uint256 tokenId, uint256 buyAmount) public {
        uint256 amount = buyAmount * _jots[tokenId].fractionPrices;
        require(amount > 0, "Amount can't be zero!");

        // Calculate amount left
        uint256 amountLeft = _jots[tokenId].sellingSupply - _jots[tokenId].soldSupply;

        // If amount left is lesser than buying amount
        // then buying amount = amount left

        if (amountLeft < amount) {
            amount = amountLeft;
        }

        // Can't sell zero tokens
        require(amount != 0, "No tokens left!");

        // Transfer funding tokens
        IERC20(fundingTokenAddress).transferFrom(msg.sender, address(this), amount);

        // Transfer Jots
        IJot(jotAddress).transferFrom(address(this), msg.sender, buyAmount);

        //Increase sold supply (amount in token) and liquidity sold (amount in ether)
        _jots[tokenId].soldSupply += buyAmount;
        _jots[tokenId].liquiditySold += amount;

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
        require(msg.sender == getSyntheticNFTOwner(tokenId), "You are not the owner of the NFT!");
        require(_jots[tokenId].ownerSupply >= amount, "You do not have enough tokens left");
        _jots[tokenId].ownerSupply -= amount;
        _jots[tokenId].sellingSupply += amount / 2;
        _jots[tokenId].liquiditySupply += amount / 2;
    }

    /**
     * @notice decrease selling supply for a given NFT
     * caller must be the owner of the NFT
     */
    function decreaseSellingSupply(uint256 tokenId, uint256 amount) public {
        require(msg.sender == getSyntheticNFTOwner(tokenId), "You are not the owner of the NFT!");
        require(_jots[tokenId].liquiditySupply >= amount / 2, "You do not have enough liquidity left");
        require(_jots[tokenId].sellingSupply >= amount / 2, "You do not have enough selling supply left");

        _jots[tokenId].ownerSupply += amount;
        _jots[tokenId].sellingSupply -= amount / 2;
        _jots[tokenId].liquiditySupply -= amount / 2;
    }

    /**
     * @notice update the price of a fraction for a given NFT
     * caller must be the owner
     */
    function updatePriceFraction(uint256 tokenId, uint256 newFractionPrice) public {
        require(msg.sender == getSyntheticNFTOwner(tokenId), "You are not the owner of the NFT!");
        _jots[tokenId].fractionPrices = newFractionPrice;
    }

    /**
     * @notice add available liquidity for a given token to UniSwap pool
     */
    function addLiquidityToPool(uint256 tokenId) public {
        uint256 liquiditySupply = _jots[tokenId].liquiditySupply;
        uint256 liquiditySold = _jots[tokenId].liquiditySold;

        // approve token transfer to cover all possible scenarios
        IJot(jotAddress).approve(address(uniswapV2Router), liquiditySupply);

        IERC20(fundingTokenAddress).approve(address(uniswapV2Router), liquiditySold);

        // add the liquidity
        uniswapV2Router.addLiquidity(
            jotAddress,
            fundingTokenAddress,
            liquiditySupply,
            liquiditySold,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0),
            block.timestamp
        );
    }

    function isAllowedToFlip(uint256 tokenId) public view returns (bool) {
        return
            // solhint-disable-next-line
            block.timestamp - _jots[tokenId].lastFlipTime >= protocol.flippingInterval() &&
            IERC20(jotAddress).balanceOf(jotPool) > 0 &&
            isSyntheticNFTFractionalised(tokenId);
    }

    function flipJot(uint256 tokenId, uint256 prediction) public {
        require(isAllowedToFlip(tokenId), "Flip is not allowed yet");
        _jots[tokenId].lastFlipTime = block.timestamp; // solhint-disable-line

        bytes32 requestId = RandomNumberConsumer(_randomConsumerAddress).getRandomNumber();
        _flips[requestId] = Flip({tokenId: tokenId, prediction: prediction});

        emit CoinFlipped(requestId, msg.sender, tokenId, prediction);
    }

    function processFlipResult(uint256 randomNumber, bytes32 requestId) external onlyRole(RANDOM_ORACLE) {
        uint256 poolAmount;
        uint256 fAmount = protocol.flippingAmount();
        uint256 fReward = protocol.flippingReward();

        Flip memory flip = _flips[requestId];
        uint256 ownerSupply = _jots[flip.tokenId].ownerSupply;

        // avoid underflow in math operations
        if (fAmount > ownerSupply) {
            fAmount = ownerSupply;
        }
        if (fReward > fAmount) {
            fReward = fAmount;
        }

        if (randomNumber == 0) {
            _jots[flip.tokenId].ownerSupply -= fAmount;
            if (randomNumber != flip.prediction) {
                poolAmount = fAmount;
            } else {
                poolAmount = fAmount - fReward;
                IERC20(jotAddress).safeTransfer(msg.sender, fReward);
            }
            if (poolAmount > 0) {
                IERC20(jotAddress).safeTransfer(jotPool, poolAmount);
            }
        } else {
            _jots[flip.tokenId].ownerSupply += fAmount;
            if (randomNumber != flip.prediction) {
                poolAmount = fAmount;
            } else {
                poolAmount = fAmount - fReward;
                IERC20(jotAddress).safeTransfer(msg.sender, fReward);
            }
            if (poolAmount > 0) {
                IERC20ManagedAccounts(jotAddress).transferFromManaged(jotPool, address(this), poolAmount);
            }
        }

        // lock the nft and make it auctionable
        if (_jots[flip.tokenId].ownerSupply == 0) {
            lockedNFTs[flip.tokenId] = true;
            AuctionsManager(_auctionsManagerAddress).whitelistNFT(flip.tokenId);
        }

        emit FlipProcessed(requestId, flip.tokenId, flip.prediction, randomNumber);
    }

    /**
     * @dev burn a token
     */
    function safeBurn(uint256 tokenId) public onlyRole(ROUTER) {
        ISyntheticNFT(erc721address).safeBurn(tokenId);
        _tokenCounter.decrement();
    }

    function getRemainingSupply(uint256 tokenId) public view returns (uint256) {
        return _jots[tokenId].ownerSupply;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
