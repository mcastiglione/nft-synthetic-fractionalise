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
import "../chainlink/PolygonValidatorOracle.sol";
import "../SyntheticProtocolRouter.sol";
import "../Interfaces.sol";
import "../governance/ProtocolParameters.sol";
import "./Jot.sol";
import "./Structs.sol";

contract SyntheticCollectionManager is AccessControl, Initializable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    bytes32 public constant ROUTER = keccak256("ROUTER");
    bytes32 public constant AUCTION_MANAGER = keccak256("AUCTION_MANAGER");
    bytes32 public constant RANDOM_ORACLE = keccak256("RANDOM_ORACLE");
    bytes32 public constant VALIDATOR_ORACLE = keccak256("VALIDATOR_ORACLE");

    address private immutable _randomConsumerAddress;
    address private immutable _validatorAddress;
    address private _auctionsManagerAddress;

    /**
     * @dev ERC20 totalSupply (governance) parameter
     * TODO: get from governance
     */
    uint256 private _jotsSupply;

    /**
     * @dev mapping the request id with the flip input data
     */
    mapping(bytes32 => Flip) private _flips;

    mapping(uint256 => uint256) private _originalToSynthetic;

    Counters.Counter public tokenCounter;

    /**
     * @notice the address of the Protocol Router
     */
    address public syntheticProtocolRouterAddress;

    ProtocolParameters public protocol;

    /**
     * @notice address of the original collection
     */
    address public originalCollectionAddress;

    /**
     * @notice jot Address for this collection
     */
    address public jotAddress;

    /**
     * @notice funding token address
     */
    address public fundingTokenAddress;

    /**
     * @notice data for each token
     */
    mapping(uint256 => TokenData) public tokens;

    /**
     * @notice the nft should be auctioned to unlock it
     */
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

    constructor(address randomConsumerAddress, address validatorAddress) {
        _randomConsumerAddress = randomConsumerAddress;
        _validatorAddress = validatorAddress;
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
        originalCollectionAddress = originalCollectionAddress_;
        syntheticProtocolRouterAddress = msg.sender;
        _auctionsManagerAddress = auctionManagerAddress;
        protocol = ProtocolParameters(protocol_);
        jotPool = jotPool_;

        _jotsSupply = protocol.jotsSupply();
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
        TokenData storage data = tokens[nftId_];

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
     * @notice change an NFT for another one of the same collection
     */
    function change(
        uint256 syntheticID,
        uint256 newOriginalTokenID,
        address caller
    ) public onlyRole(ROUTER) {
        // Token must be registered
        require(ISyntheticNFT(erc721address).exists(syntheticID), "token not registered!");

        // Caller must be token owner
        address tokenOwner = IERC721(erc721address).ownerOf(syntheticID);
        require(tokenOwner == caller, "You are not the owner of the NFT!");

        // Change original token ID and set verified = false
        uint256 originalID = tokens[syntheticID].originalID;

        _originalToSynthetic[originalID] = 0;
        _originalToSynthetic[newOriginalTokenID] = syntheticID;

        tokens[syntheticID].originalID = newOriginalTokenID;
        tokens[syntheticID].verified = false;
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
     * been already fractionalized
     */
    function isSyntheticNFTCreated(uint256 tokenId) public view returns (bool) {
        return _originalToSynthetic[tokenId] != 0;
    }

    /**
     * @notice public function. Checks if an NFT has
     * been already fractionalised.
     */
    function isSyntheticNFTFractionalised(uint256 tokenId) public view returns (bool) {
        return tokens[tokenId].ownerSupply != 0;
    }

    /**
     * @notice Checks isSyntheticNFTCreated(address, id) is False.
     * Then it mints a new NFT with: ”to”, ”id” and ”metadata”
     */
    function generateSyntheticNFT(address to, uint256 tokenId) private {
        ISyntheticNFT(erc721address).safeMint(to, tokenId);
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
        uint256 priceFraction,
        address nftOwner
    ) public onlyRole(ROUTER) returns (uint256) {
        require(priceFraction > 0, "priceFraction can't be zero");
        require(isSyntheticNFTCreated(tokenId) == false, "Synthetic NFT already generated!");

        uint256 syntheticID = tokenCounter.current();

        generateSyntheticNFT(nftOwner, syntheticID); 
 
        Jot(jotAddress).mint(address(this), _jotsSupply); 

        uint256 sellingSupply = (_jotsSupply - supplyToKeep) / 2;
        uint256 liquiditySupply = (_jotsSupply - supplyToKeep) / 2;

        TokenData memory data = TokenData({
            originalTokenID: tokenId,
            ownerSupply: supplyToKeep,
            sellingSupply: sellingSupply,
            soldSupply: 0,
            liquiditySupply: liquiditySupply,
            liquiditySold: 0,
            fractionPrices: priceFraction,
            lastFlipTime: 0,
            verified: false,
            originalID: 0
        });

        tokens[syntheticID] = data;

        tokenCounter.increment();

        return syntheticID;
    }

    function getOwnerSupply(uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].ownerSupply;
    }

    function getSellingSupply(uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].sellingSupply;
    }

    function getSoldSupply(uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].soldSupply;
    }

    function getJotFractionPrice(uint256 tokenId) public view returns(uint256) {
        return tokens[tokenId].fractionPrices;
    }

    function getJotAmountLeft(uint256 tokenId) public view returns(uint256) {
        return tokens[tokenId].sellingSupply - tokens[tokenId].soldSupply;
    }

    /**
     * @notice allows the caller to buy jots using the Funding token
     */
    function buyJotTokens(uint256 tokenId, uint256 buyAmount) public {
        require(ISyntheticNFT(erc721address).exists(tokenId), "Token not registered");
        require(tokens[tokenId].fractionPrices > 0, "Token price not set");
        uint256 amount = (buyAmount * tokens[tokenId].fractionPrices) / 10**18;
        require(amount > 0, "Amount can't be zero!");

        // Calculate amount left
        uint256 amountLeft = tokens[tokenId].sellingSupply - tokens[tokenId].soldSupply;

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
        IJot(jotAddress).transfer(msg.sender, buyAmount);

        //Increase sold supply (amount in token) and liquidity sold (amount in ether)
        tokens[tokenId].soldSupply += buyAmount;
        tokens[tokenId].liquiditySold += amount;

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
        require(tokens[tokenId].ownerSupply >= amount, "You do not have enough tokens left");
        tokens[tokenId].ownerSupply -= amount;
        tokens[tokenId].sellingSupply += amount / 2;
        tokens[tokenId].liquiditySupply += amount / 2;
    }

    /**
     * @notice decrease selling supply for a given NFT
     * caller must be the owner of the NFT
     */
    function decreaseSellingSupply(uint256 tokenId, uint256 amount) public {
        require(msg.sender == getSyntheticNFTOwner(tokenId), "You are not the owner of the NFT!");
        require(tokens[tokenId].liquiditySupply >= amount / 2, "You do not have enough liquidity left");
        require(tokens[tokenId].sellingSupply >= amount / 2, "You do not have enough selling supply left");

        tokens[tokenId].ownerSupply += amount;
        tokens[tokenId].sellingSupply -= amount / 2;
        tokens[tokenId].liquiditySupply -= amount / 2;
    }

    /**
     * @notice update the price of a fraction for a given NFT
     * caller must be the owner
     */
    function updatePriceFraction(uint256 tokenId, uint256 newFractionPrice) public {
        require(ISyntheticNFT(erc721address).exists(tokenId), "Token not registered");
        require(msg.sender == getSyntheticNFTOwner(tokenId), "You are not the owner of the NFT!");
        tokens[tokenId].fractionPrices = newFractionPrice;
    }

    /**
     * @notice add available liquidity for a given token to UniSwap pool
     */
    function addLiquidityToPool(uint256 tokenId) public {
        uint256 liquiditySupply = tokens[tokenId].liquiditySupply;
        uint256 liquiditySold = tokens[tokenId].liquiditySold;

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
            block.timestamp // solhint-disable-line
        );
    }

    function isAllowedToFlip(uint256 tokenId) public view returns (bool) {
        return
            ISyntheticNFT(erc721address).exists(tokenId) &&
            block.timestamp - tokens[tokenId].lastFlipTime >= protocol.flippingInterval() && // solhint-disable-line
            IERC20(jotAddress).balanceOf(jotPool) > protocol.flippingAmount() &&
            isSyntheticNFTFractionalised(tokenId);
    }

    function flipJot(uint256 tokenId, uint64 prediction) external {
        require(isAllowedToFlip(tokenId), "Flip is not allowed yet");
        tokens[tokenId].lastFlipTime = block.timestamp; // solhint-disable-line

        bytes32 requestId = RandomNumberConsumer(_randomConsumerAddress).getRandomNumber();
        _flips[requestId] = Flip({tokenId: tokenId, prediction: prediction, player: msg.sender});

        emit CoinFlipped(requestId, msg.sender, tokenId, prediction);
    }

    function processFlipResult(uint256 randomNumber, bytes32 requestId) external onlyRole(RANDOM_ORACLE) {
        uint256 poolAmount;
        uint256 fAmount = protocol.flippingAmount();
        uint256 fReward = protocol.flippingReward();

        Flip memory flip = _flips[requestId];
        uint256 ownerSupply = tokens[flip.tokenId].ownerSupply;

        // avoid underflow in math operations
        if (fAmount > ownerSupply) {
            fAmount = ownerSupply;
        }
        if (fReward > fAmount) {
            fReward = fAmount;
        }

        if (randomNumber == 0) {
            tokens[flip.tokenId].ownerSupply -= fAmount;
            if (randomNumber != flip.prediction) {
                poolAmount = fAmount;
            } else {
                poolAmount = fAmount - fReward;
                IERC20(jotAddress).safeTransfer(_flips[requestId].player, fReward);
            }
            if (poolAmount > 0) {
                IERC20(jotAddress).safeTransfer(jotPool, poolAmount);
            }
        } else {
            tokens[flip.tokenId].ownerSupply += fAmount;
            if (randomNumber != flip.prediction) {
                poolAmount = fAmount;
            } else {
                poolAmount = fAmount - fReward;
                IERC20(jotAddress).safeTransfer(_flips[requestId].player, fReward);
            }
            if (poolAmount > 0) {
                IERC20ManagedAccounts(jotAddress).transferFromManaged(jotPool, address(this), poolAmount);
            }
        }

        // lock the nft and make it auctionable
        if (tokens[flip.tokenId].ownerSupply == 0) {
            lockedNFTs[flip.tokenId] = true;
            AuctionsManager(_auctionsManagerAddress).whitelistNFT(flip.tokenId);
        }

        emit FlipProcessed(requestId, flip.tokenId, flip.prediction, randomNumber);
    }

    /**
     * @notice This method calls chainlink oracle and
     * verifies if the NFT has been locked on NFTVaultManager. In addition
     * gets the metadata of the NFT
     */
    function verify(uint256 tokenId) external {
        require(ISyntheticNFT(erc721address).exists(tokenId), "Token not registered");
        require(!tokens[tokenId].verified, "Token already verified");
        PolygonValidatorOracle(_validatorAddress).verifyTokenInCollection(
            originalCollectionAddress,
            tokens[tokenId].originalTokenID
        );
    }

    function processSuccessfulVerify(uint256 tokenId) external onlyRole(VALIDATOR_ORACLE) {
        tokens[tokenId].verified = true;
    }

    /**
     * @dev burn a token
     */
    function safeBurn(uint256 tokenId) public onlyRole(ROUTER) {
        ISyntheticNFT(erc721address).safeBurn(tokenId);
        tokenCounter.decrement();
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function isVerified(uint256 tokenId) public view returns (bool) {
        require(ISyntheticNFT(erc721address).exists(tokenId), "NFT not minted");
        return tokens[tokenId].verified;
    }

    function getOriginalID(uint256 tokenId) public view returns (uint256) {
        require(ISyntheticNFT(erc721address).exists(tokenId));
        return tokens[tokenId].originalID;
    }
}
