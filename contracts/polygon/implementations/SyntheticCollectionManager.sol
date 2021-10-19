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
import "../chainlink/RandomNumberConsumer.sol";
import "../chainlink/PolygonValidatorOracle.sol";
import "../chainlink//OracleStructs.sol";
import "../libraries/ProtocolConstants.sol";
import "../governance/ProtocolParameters.sol";
import "../SyntheticProtocolRouter.sol";
import "../Interfaces.sol";
import "./Jot.sol";
import "./JotPool.sol";
import "./RedemptionPool.sol";
import "./Structs.sol";
import "./Enums.sol";

import {AuctionsManager} from "../auctions/AuctionsManager.sol";

/**
 * @title synthetic collection abstraction contract
 * @author priviprotocol
 */
contract SyntheticCollectionManager is AccessControl, Initializable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    /// @notice role of the router contract
    bytes32 public constant ROUTER = keccak256("ROUTER");

    /// @notice role of the auctions manager fabric contract
    bytes32 public constant AUCTION_MANAGER = keccak256("AUCTION_MANAGER");

    /// @notice role of the vrf chainlink oracle
    bytes32 public constant RANDOM_ORACLE = keccak256("RANDOM_ORACLE");

    /// @notice role of the polygon validator chainlink oracle for verifications
    bytes32 public constant VALIDATOR_ORACLE = keccak256("VALIDATOR_ORACLE");

    // the price to buyback an NFT (buying Jots) and exit the protocol
    uint256 public buybackPrice;

    // address of the vrf chainlink oracle contract
    address private immutable _randomConsumerAddress;

    // address of the polygon validator chainlink oracle contract
    address private immutable _validatorAddress;

    Counters.Counter public tokenCounter;

    /// @notice the address of the auctions manager fabric contract
    address public auctionsManagerAddress;

    /// @notice the address of the protocol router
    address public syntheticProtocolRouterAddress;

    address private _perpetualPoolLiteAddress;

    address private _swapAddress;

    /// @dev mapping the request id from Chainlink with the flip input data
    mapping(bytes32 => Flip) private _flips;

    mapping(uint256 => uint256) private _originalToSynthetic;

    ProtocolParameters public protocol;

    /// @notice address of the original collection
    address public originalCollectionAddress;

    /// @notice jot Address for this collection
    address public jotAddress;

    /// @notice funding token address
    address public fundingTokenAddress;

    /// @notice data for each token
    mapping(uint256 => TokenData) public tokens;

    /// @dev the nonce to avoid double verification (quantity of exits for original token id)
    mapping(uint256 => uint256) public nonces;

    /**
     * @dev nonce to count the changes of an original collection token id
     *      in order to avoid double change (with the second one keeping the synthetic playing)
     */
    mapping(uint256 => ChangeNonce) public changeNonces;

    mapping(uint256 => mapping(uint256 => address)) public ownersByNonce;

    /// @notice Synthetic NFT Address  for this collection
    address public erc721address;

    address public jotPool;
    address public redemptionPool;

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

    event VerificationRequested(bytes32 indexed requestId, address from, uint256 tokenId);

    event VerifyResponseReceived(
        bytes32 indexed requestId,
        address originalCollection,
        address syntheticCollection,
        uint256 tokenId,
        bool verified
    );

    event TokenReassigned(uint256 tokenID, address newOwner);

    event LiquidityRemoved(uint256 jotAmount, uint256 fundingAmount);

    /**
     * @dev initializes some immutable variables and lock the implementation contract
     *      for further initializations (with the initializer modifier)
     *
     * @param randomConsumerAddress_ the address of the vrf Chainlink node
     * @param validatorAddress_ the address of the polygon validator Chainlink node
     */
    constructor(address randomConsumerAddress_, address validatorAddress_) initializer {
        _randomConsumerAddress = randomConsumerAddress_;
        _validatorAddress = validatorAddress_;
    }

    /**
     * @dev initialize the proxy contract
     * @param jotAddress_ the address of the jot contract for this collection
     * @param originalCollectionAddress_ the original collection address
     * @param erc721address_ the address of the synthetic erc721 contract handled by this
     * @param auctionManagerAddress_ the auctions manager fabric address
     * @param protocol_ the address of the protocol parameters contract (governance parameters)
     * @param jotPool_ the address of the corresponding jot pool
     * @param redemptionPool_ the address of the corresponding redemption pool
     * @param swapAddress_ the address of the uniswapV2Pair
     */
    function initialize(
        address jotAddress_,
        address originalCollectionAddress_,
        address erc721address_,
        address auctionManagerAddress_,
        address protocol_,
        address jotPool_,
        address redemptionPool_,
        address swapAddress_
    ) external initializer {
        jotAddress = jotAddress_;
        erc721address = erc721address_;
        originalCollectionAddress = originalCollectionAddress_;
        syntheticProtocolRouterAddress = msg.sender;
        auctionsManagerAddress = auctionManagerAddress_;
        protocol = ProtocolParameters(protocol_);
        jotPool = jotPool_;
        redemptionPool = redemptionPool_;
        buybackPrice = 10**18;

        _swapAddress = swapAddress_;

        // we need to initialize this member here because we need to continue using this if governance changes it
        fundingTokenAddress = ProtocolParameters(protocol_).fundingTokenAddress();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ROUTER, msg.sender);
        _setupRole(AUCTION_MANAGER, auctionManagerAddress_);
    }

    /**
     * @dev allows the callback after finishing an auction to reassign the NFT to the winner
     * @param nftId_ the id of the auctioned synthetic token
     * @param newOwner_ the winner of the auction account
     */
    function reassignNFT(uint256 nftId_, address newOwner_) external onlyRole(AUCTION_MANAGER) {
        string memory metadata = ISyntheticNFT(erc721address).tokenURI(nftId_);

        TokenData storage data = tokens[nftId_];

        // the auction could only be started if ownerSupply is 0
        assert(data.ownerSupply == 0);

        // Get original token ID
        uint256 originalID = tokens[nftId_].originalTokenID;

        // Burn synthetic NFT
        ISyntheticNFT(erc721address).safeBurn(nftId_);

        // Get new synthetic ID
        uint256 newSyntheticID = tokenCounter.current();

        // Mint new one
        ISyntheticNFT(erc721address).safeMint(newOwner_, newSyntheticID, metadata);

        // Update original to synthetic mapping
        _originalToSynthetic[originalID] = newSyntheticID;

        // Empty previous id
        tokens[nftId_] = TokenData(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, State.NEW);

        // Fill new ID
        tokens[newSyntheticID] = TokenData(
            originalID,
            ProtocolConstants.JOT_SUPPLY,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            State.VERIFIED
        );

        emit TokenReassigned(newSyntheticID, newOwner_);
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
        address nftOwner,
        string memory metadata
    ) public onlyRole(ROUTER) returns (uint256) {
        require(priceFraction > 0, "priceFraction can't be zero");
        require(isSyntheticNFTCreated(tokenId) == false, "Synthetic NFT already generated!");

        uint256 syntheticID = tokenCounter.current();

        ISyntheticNFT(erc721address).safeMint(nftOwner, syntheticID, metadata);

        Jot(jotAddress).mint(address(this), ProtocolConstants.JOT_SUPPLY);

        uint256 sellingSupply = (ProtocolConstants.JOT_SUPPLY - supplyToKeep) / 2;
        uint256 liquiditySupply = (ProtocolConstants.JOT_SUPPLY - supplyToKeep) / 2;

        TokenData memory data = TokenData({
            originalTokenID: tokenId,
            ownerSupply: supplyToKeep,
            sellingSupply: sellingSupply,
            soldSupply: 0,
            liquiditySupply: liquiditySupply,
            liquiditySold: 0,
            fractionPrices: priceFraction,
            lastFlipTime: 0,
            liquidityTokenBalance: 0,
            UniswapJotLiquidity: 0,
            UniswapFundingLiquidity: 0,
            state: State.NEW
        });

        tokens[syntheticID] = data;

        // lock the nft and make it auctionable
        if (supplyToKeep == 0) {
            AuctionsManager(auctionsManagerAddress).whitelistNFT(syntheticID);
        }

        tokenCounter.increment();

        return syntheticID;
    }

    /**
     * @notice allows the caller to buy jots using the Funding token
     */
    function buyJotTokens(uint256 tokenId, uint256 buyAmount) public {
        TokenData storage token = tokens[tokenId];
        require(ISyntheticNFT(erc721address).exists(tokenId), "Token not registered");
        require(!lockedNFT(tokenId), "Token is locked!");
        require(buyAmount > 0, "Buy amount can't be zero!");

        // Calculate amount left
        uint256 amountLeft = token.sellingSupply - token.soldSupply;

        // If amount left is lesser than buying amount
        // then buying amount = amount left
        if (amountLeft < buyAmount) {
            buyAmount = amountLeft;
        }

        uint256 amount = (buyAmount * token.fractionPrices) / 10**18;
        // Can't sell zero tokens
        require(amount != 0, "No tokens left!");

        // Transfer funding tokens
        IERC20(fundingTokenAddress).transferFrom(msg.sender, address(this), amount);

        // Transfer Jots
        IJot(jotAddress).transfer(msg.sender, buyAmount);

        //Increase sold supply (amount in token) and liquidity sold (amount in ether)
        token.soldSupply += buyAmount;
        token.liquiditySold += amount;
    }

    function depositJots(uint256 tokenId, uint256 amount) public {
        require(amount > 0, "Amount can't be zero!");
        ISyntheticNFT nft = ISyntheticNFT(erc721address);
        address nftOwner = nft.ownerOf(tokenId);
        require(nftOwner == msg.sender, "you are not the owner of the NFT!");
        require(!lockedNFT(tokenId), "Token is locked!");
        uint256 result = tokens[tokenId].ownerSupply + amount;
        require(result <= ProtocolConstants.JOT_SUPPLY, "You can't deposit more than the Jot Supply limit");
        IJot(jotAddress).transferFrom(msg.sender, address(this), amount);
        tokens[tokenId].ownerSupply += amount;
    }

    function withdrawJots(uint256 tokenId, uint256 amount) public {
        ISyntheticNFT nft = ISyntheticNFT(erc721address);
        address nftOwner = nft.ownerOf(tokenId);
        require(nftOwner == msg.sender, "you are not the owner of the NFT!");
        require(!lockedNFT(tokenId), "Token is locked!");
        require(amount <= tokens[tokenId].ownerSupply, "Not enough balance");
        tokens[tokenId].ownerSupply -= amount;
        IJot(jotAddress).transfer(msg.sender, amount);
        if (tokens[tokenId].ownerSupply == 0) {
            AuctionsManager(auctionsManagerAddress).whitelistNFT(tokenId);
        }
    }

    /**
     * @notice increase selling supply for a given NFT
     * caller must be the owner of the NFT
     */

    function increaseSellingSupply(uint256 tokenId, uint256 amount) public {
        TokenData storage token = tokens[tokenId];
        require(msg.sender == getSyntheticNFTOwner(tokenId), "You are not the owner of the NFT!");
        require(amount > 0, "Amount can't be zero!");
        require(!lockedNFT(tokenId), "Token is locked!");

        require(token.ownerSupply >= amount, "You do not have enough tokens left");
        token.ownerSupply -= amount;
        token.sellingSupply += amount / 2;
        token.liquiditySupply += amount / 2;

        // lock the nft and make it auctionable
        if (token.ownerSupply == 0) {
            AuctionsManager(auctionsManagerAddress).whitelistNFT(tokenId);
        }
    }

    /**
     * @notice decrease selling supply for a given NFT
     * caller must be the owner of the NFT
     */
    function decreaseSellingSupply(uint256 tokenId, uint256 amount) public {
        TokenData storage token = tokens[tokenId];

        require(msg.sender == getSyntheticNFTOwner(tokenId), "You are not the owner of the NFT!");
        require(amount > 0, "Amount can't be zero!");

        require(!lockedNFT(tokenId), "Token is locked!");

        require(token.liquiditySupply >= amount / 2, "You do not have enough liquidity left");
        require(token.sellingSupply >= amount / 2, "You do not have enough selling supply left");

        token.ownerSupply += amount;
        token.sellingSupply -= amount / 2;
        token.liquiditySupply -= amount / 2;
    }

    /**
     * @notice update the price of a fraction for a given NFT
     * caller must be the owner
     */
    function updatePriceFraction(uint256 tokenId, uint256 newFractionPrice) public {
        require(ISyntheticNFT(erc721address).exists(tokenId), "Token not registered");
        require(newFractionPrice > 0, "Fraction price must be greater than zero");
        require(msg.sender == getSyntheticNFTOwner(tokenId), "You are not the owner of the NFT!");
        require(!lockedNFT(tokenId), "Token is locked!");

        TokenData storage token = tokens[tokenId];

        token.fractionPrices = newFractionPrice;
    }

    /**
     * @notice add available liquidity for a given token to UniSwap pool
     */
    function addLiquidityToPool(uint256 tokenId) public {
        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(_swapAddress);

        TokenData storage token = tokens[tokenId];
        require(tokens[tokenId].soldSupply > 0, "soldSupply is zero");
        uint256 liquiditySupply = token.liquiditySupply;
        uint256 liquiditySold = token.liquiditySold;

        IJot(jotAddress).approve(_swapAddress, liquiditySupply);

        IERC20(fundingTokenAddress).approve(_swapAddress, liquiditySold);

        uint256 amountA;
        uint256 amountB;
        uint256 liquidity;

        // add the liquidity
        (amountA, amountB, liquidity) = uniswapV2Router.addLiquidity(
            jotAddress,
            fundingTokenAddress,
            liquiditySupply,
            liquiditySold,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp // solhint-disable-line
        );

        if (amountB < liquiditySold) {
            uint256 funding_remaining = liquiditySold - amountB;

            IERC20(fundingTokenAddress).approve(_perpetualPoolLiteAddress, funding_remaining);
            IPerpetualPoolLite(_perpetualPoolLiteAddress).addLiquidity(funding_remaining);
        }

        unchecked {
            tokens[tokenId].liquiditySupply -= amountA;
            tokens[tokenId].liquiditySold -= liquiditySold;
            tokens[tokenId].sellingSupply -= amountA;
            tokens[tokenId].soldSupply -= liquiditySold;
            tokens[tokenId].liquidityTokenBalance += liquidity;
            tokens[tokenId].UniswapJotLiquidity += amountA;
            tokens[tokenId].UniswapFundingLiquidity += amountB;
        }
    }

    /**
     * @notice Remove liquidity from pool only callable by AuctionsManager
     */
    function removeLiquidityFromPool(uint256 tokenId) external onlyRole(AUCTION_MANAGER) {
        address tokenOwner = ISyntheticNFT(erc721address).ownerOf(tokenId);

        uint256 jotLiquidity;
        uint256 fundingLiquidity;

        (jotLiquidity, fundingLiquidity) = _removeLiquidityFromPool(tokenId);
        tokens[tokenId].ownerSupply += jotLiquidity;
        // transfer funding token balance to caller
        IERC20(fundingTokenAddress).transfer(tokenOwner, fundingLiquidity);
    }

    /**
     * @dev remove liquidity from Pool
     */
    function _removeLiquidityFromPool(uint256 tokenId) internal returns (uint256, uint256) {
        TokenData storage token = tokens[tokenId];

        IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(Jot(jotAddress).uniswapV2Pair());

        // get added liquidity
        uint256 jotLiquidity = token.UniswapJotLiquidity;
        uint256 fundingLiquidity = token.UniswapFundingLiquidity;
        uint256 liquidityTokenBalance = token.liquidityTokenBalance;

        if (liquidityTokenBalance == 0 || jotLiquidity == 0 || fundingLiquidity == 0) {
            return (0, 0);
        }

        uint256 liquidityTokenBalanceUniswap = uniswapV2Pair.balanceOf(address(this));

        if (liquidityTokenBalanceUniswap < liquidityTokenBalance) {
            liquidityTokenBalance = liquidityTokenBalanceUniswap;
        }

        // approve liquidity transfer
        uniswapV2Pair.approve(_swapAddress, liquidityTokenBalance);

        // pair reserves in Uniswap Pair
        uint112 jotReserves;
        uint112 fundingReserves;
        uint32 blockTimestampLast;

        (jotReserves, fundingReserves, blockTimestampLast) = uniswapV2Pair.getReserves();

        // handle low balance edge cases
        if (jotLiquidity > jotReserves) {
            jotLiquidity = jotReserves;
        }

        if (fundingLiquidity > fundingReserves) {
            fundingLiquidity = fundingReserves;
        }

        if (jotReserves == 0 || fundingReserves == 0) {
            return (0, 0);
        }

        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(_swapAddress);

        // actual liquidity removed
        uint256 jotAmountExecuted;
        uint256 fundingAmountExecuted;

        // call Uniswap to remove liquidity
        (jotAmountExecuted, fundingAmountExecuted) = uniswapV2Router.removeLiquidity(
            jotAddress,
            fundingTokenAddress,
            liquidityTokenBalance,
            jotLiquidity,
            fundingLiquidity,
            address(this),
            block.timestamp // solhint-disable-line
        );

        emit LiquidityRemoved(jotAmountExecuted, fundingAmountExecuted);

        return (jotAmountExecuted, fundingAmountExecuted);
    }

    /**
     * @notice Claim Liquidity Tokens
     */
    function claimLiquidityTokens(uint256 tokenId, uint256 amount) public {
        address tokenOwner = ISyntheticNFT(erc721address).ownerOf(tokenId);
        require(msg.sender == tokenOwner, "You are not the owner");

        uint256 availableAmount = tokens[tokenId].liquidityTokenBalance;
        require(amount <= availableAmount, "Not enough liquidity available");

        IUniswapV2Pair pair = IUniswapV2Pair(poolAddress());

        tokens[tokenId].liquidityTokenBalance -= amount;

        pair.transfer(msg.sender, amount);
    }

    function flipJot(uint256 tokenId, uint64 prediction) external {
        TokenData storage token = tokens[tokenId];

        require(isAllowedToFlip(tokenId), "Flip is not allowed yet");
        require(!lockedNFT(tokenId), "Token is locked!");

        token.lastFlipTime = block.timestamp; // solhint-disable-line

        bytes32 requestId = RandomNumberConsumer(_randomConsumerAddress).getRandomNumber();
        _flips[requestId] = Flip({tokenId: tokenId, prediction: prediction, player: msg.sender});

        emit CoinFlipped(requestId, msg.sender, tokenId, prediction);
    }

    function processFlipResult(uint256 randomNumber, bytes32 requestId) external onlyRole(RANDOM_ORACLE) {
        uint256 poolAmount;
        uint256 fAmount = protocol.flippingAmount();
        uint256 fReward = protocol.flippingReward();

        Flip memory flip = _flips[requestId];
        TokenData storage token = tokens[flip.tokenId];
        uint256 ownerSupply = token.ownerSupply;

        // avoid underflow in math operations
        if (fAmount > ownerSupply) {
            fAmount = ownerSupply;
        }
        if (fReward > fAmount) {
            fReward = fAmount;
        }

        if (randomNumber == 0) {
            token.ownerSupply -= fAmount;
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
            token.ownerSupply += fAmount;
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
        if (token.ownerSupply == 0) {
            AuctionsManager(auctionsManagerAddress).whitelistNFT(flip.tokenId);
        }

        emit FlipProcessed(requestId, flip.tokenId, flip.prediction, randomNumber);
    }

    function recoverToken(uint256 tokenId) external {
        require(AuctionsManager(auctionsManagerAddress).isRecoverable(tokenId), "Token is not recoverable");
        require(ISyntheticNFT(erc721address).ownerOf(tokenId) == msg.sender, "Only owner allowed");

        // reverts on failure
        IERC20(jotAddress).safeTransferFrom(msg.sender, address(this), ProtocolConstants.JOT_SUPPLY);

        tokens[tokenId].ownerSupply = ProtocolConstants.JOT_SUPPLY;

        AuctionsManager(auctionsManagerAddress).blacklistNFT(tokenId);
    }

    /**
     * @notice This method calls chainlink oracle and
     * verifies if the NFT has been locked on NFTVaultManager. In addition
     * gets the metadata of the NFT
     */
    function verify(uint256 tokenId) external {
        TokenData storage token = tokens[tokenId];
        require(ISyntheticNFT(erc721address).exists(tokenId), "Token not registered");
        require(token.state != State.VERIFIED, "Token already verified");

        token.state = State.VERIFYING;

        bytes32 requestId = PolygonValidatorOracle(_validatorAddress).verifyTokenInCollection(
            originalCollectionAddress,
            tokenId,
            uint256(token.state),
            nonces[token.originalTokenID]
        );

        emit VerificationRequested(requestId, msg.sender, tokenId);
    }

    function processVerifyResponse(
        bytes32 requestId,
        VerifyRequest memory requestData,
        bool verified
    ) external onlyRole(VALIDATOR_ORACLE) {
        TokenData storage token = tokens[requestData.tokenId];

        if (verified) {
            token.state = State.VERIFIED;
        } else {
            token.state = requestData.previousState;
        }

        emit VerifyResponseReceived(
            requestId,
            requestData.originalCollection,
            requestData.syntheticCollection,
            requestData.tokenId,
            verified
        );
    }

    /**
     * @notice change an NFT for another one of the same collection
     */
    function change(
        uint256 syntheticId,
        uint256 newOriginalId,
        string memory metadata,
        address caller
    ) public onlyRole(ROUTER) {
        TokenData storage token = tokens[syntheticId];

        // only can change tokens with supply
        require(token.ownerSupply > 0, "Can't be changed");

        // should be verified
        require(token.state == State.VERIFIED, "Token not verified");

        // caller must be tokens owner
        require(IERC721(erc721address).ownerOf(syntheticId) == caller, "Should own NFT");

        // updates the nonce for change
        ChangeNonce storage cn = changeNonces[token.originalTokenID];
        cn.nonce += 1;
        cn.newTokenId = newOriginalId;
        cn.owner = caller;

        token.state = State.CHANGING;
        delete _originalToSynthetic[token.originalTokenID];
        token.originalTokenID = newOriginalId;
        _originalToSynthetic[newOriginalId] = syntheticId;

        ISyntheticNFT(erc721address).setMetadata(syntheticId, metadata);
    }

    /**
     * @notice returns funds owned by token, in Jots and Funding, in contract and in UniSwap
     */
    function getAvailableJotsForBuyback(uint256 tokenId)
        public
        view
        returns (uint256 totalJots, uint256 totalFunding)
    {
        TokenData storage token = tokens[tokenId];

        IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(Jot(jotAddress).uniswapV2Pair());

        uint256 liquidity = token.liquidityTokenBalance;

        uint256 liquidityUniswap = uniswapV2Pair.balanceOf(address(this));

        if (liquidityUniswap < liquidity) {
            liquidity = liquidityUniswap;
        }

        (uint112 jotReserves, uint112 fundingReserves, ) = uniswapV2Pair.getReserves();

        uint256 totalSupply = uniswapV2Pair.totalSupply();

        uint256 jotLiquidity = (liquidity * jotReserves) / totalSupply;

        // the funding liquidity is the total funding
        totalFunding = (liquidity * fundingReserves) / totalSupply;

        totalJots = token.ownerSupply + token.sellingSupply + token.liquiditySupply + jotLiquidity;
    }

    function buybackRequiredAmount(uint256 tokenId)
        public
        view
        returns (uint256 buybackAmount, uint256 fundingLeft)
    {
        require(ISyntheticNFT(erc721address).ownerOf(tokenId) == msg.sender, "Only owner allowed");
        require(!lockedNFT(tokenId), "Token is locked!");

        (uint256 total, uint256 fundingLiquidity) = getAvailableJotsForBuyback(tokenId);

        (fundingLeft, buybackAmount) = _getFundingLeftAndBuybackAmount(total, fundingLiquidity);
    }

    /**
     * @notice Buy token back.
     * Caller needs to pre-approve a transaction worth the amount
     * returned by the getRequiredFundingForBuyback(uint256 tokenId) function
     */
    function buyback(uint256 tokenId) public {
        require(ISyntheticNFT(erc721address).ownerOf(tokenId) == msg.sender, "Only owner allowed");
        require(!lockedNFT(tokenId), "Token is locked!");

        // execute the buyback if needed and remove the liquidity
        _executeBuyback(tokenId);

        // exit the protocol
        _exitProtocol(tokenId);
    }

    /**
     * @dev helper for the buyback function
     */
    function _executeBuyback(uint256 tokenId) internal {
        TokenData storage token = tokens[tokenId];

        // get available liquidity (owner + selling + liquidity + uniswap )
        (uint256 jotLiquidity, uint256 fundingLiquidity) = _removeLiquidityFromPool(tokenId);

        // TODO: get PerpetualPoolLite.getLiquidity
        //uint256 perpetualPoolLiteLiquidity;

        uint256 total = token.ownerSupply + token.sellingSupply + token.liquiditySupply + jotLiquidity;

        (uint256 fundingLeft, uint256 buybackAmount) = _getFundingLeftAndBuybackAmount(
            total,
            fundingLiquidity
        );

        uint256 burned = total < ProtocolConstants.JOT_SUPPLY ? total : ProtocolConstants.JOT_SUPPLY;

        // burn the jots
        Jot(jotAddress).burn(burned);

        if (buybackAmount > 0) {
            // increase allowance to burn
            Jot(jotAddress).increaseAllowance(redemptionPool, ProtocolConstants.JOT_SUPPLY - burned);

            // update redemption pool balance trackers
            RedemptionPool(redemptionPool).addRedemableBalance(buybackAmount, (buybackAmount / buybackPrice));

            IERC20(fundingTokenAddress).transferFrom(msg.sender, redemptionPool, buybackAmount);
        }

        if (fundingLeft > 0) {
            IERC20(fundingTokenAddress).transfer(msg.sender, fundingLeft);
        }
    }

    /**
     * @dev helper for the execute buyback function
     */
    function _getFundingLeftAndBuybackAmount(uint256 total_, uint256 fundingLiquidity_)
        internal
        view
        returns (uint256 fundingLeft, uint256 buybackAmount)
    {
        // funding left (outstanding amount from uniswap)
        fundingLeft = (ProtocolConstants.JOT_SUPPLY >= total_) ? 0 : total_ - ProtocolConstants.JOT_SUPPLY;

        // if user has enough balance the buyback amount is 0
        buybackAmount = fundingLeft == 0
            ? ((ProtocolConstants.JOT_SUPPLY - total_) * buybackPrice) / 10**18
            : 0;

        // update amounts
        if (buybackAmount == 0) {
            fundingLeft += fundingLiquidity_;
        } else if (buybackAmount >= fundingLiquidity_) {
            buybackAmount -= fundingLiquidity_;
        } else {
            fundingLeft += fundingLiquidity_ - buybackAmount;
        }
    }

    /**
     * @dev allows to exit the protocol (retrieve the token)
     */
    function _exitProtocol(uint256 tokenId) internal {
        TokenData storage token = tokens[tokenId];

        // increase nonce to avoid double verification
        uint256 currentNonce = nonces[token.originalTokenID];
        ownersByNonce[tokenId][currentNonce] = msg.sender;
        nonces[token.originalTokenID] = currentNonce + 1;

        // Burn synthetic token
        safeBurn(tokenId);

        // free space and get refunds
        delete _originalToSynthetic[token.originalTokenID];
        delete tokens[tokenId];
    }

    /**
     * @dev burn a token
     */
    function safeBurn(uint256 tokenId) private {
        ISyntheticNFT(erc721address).safeBurn(tokenId);
        tokenCounter.decrement();
    }

    function setMetadata(uint256 tokenId, string memory metadata) public {
        TokenData storage token = tokens[tokenId];
        require(token.state != State.VERIFIED, "Can't change metadata after verify");
        require(token.state != State.VERIFYING, "Can't change metadata while verifying");

        address tokenOwner = IERC721(erc721address).ownerOf(tokenId);
        require(msg.sender == tokenOwner, "You are not the owner of the NFT!");
        ISyntheticNFT(erc721address).setMetadata(tokenId, metadata);
    }

    function exchangeOwnerJot(uint256 tokenId, uint256 amount) external {
        require(tokens[tokenId].ownerSupply >= amount, "Exchange amount exceeds balance");
        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(_swapAddress);
        address[] memory path = new address[](2);
        path[0] = jotAddress;
        path[1] = fundingTokenAddress;

        tokens[tokenId].ownerSupply -= amount;
        if (tokens[tokenId].ownerSupply == 0) {
            AuctionsManager(auctionsManagerAddress).whitelistNFT(tokenId);
        }

        uniswapV2Router.swapExactTokensForTokens(
            amount,
            0, //we don't care about slippage
            path,
            msg.sender,
            // solhint-disable-next-line
            block.timestamp
        );
    }

    function setPerpetualPoolLiteAddress(address perpetualPoolLiteAddress_) external onlyRole(ROUTER) {
        _perpetualPoolLiteAddress = perpetualPoolLiteAddress_;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function isVerified(uint256 tokenId) public view returns (bool) {
        return (tokens[tokenId].state == State.VERIFIED);
    }

    function getOriginalID(uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].originalTokenID;
    }

    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        return ISyntheticNFT(erc721address).tokenURI(tokenId);
    }

    /**
     * @notice Get the owner of the NFT
     */
    function getSyntheticNFTOwner(uint256 tokenId) public view returns (address) {
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
        return tokens[tokenId].originalTokenID != 0;
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

    function getJotFractionPrice(uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].fractionPrices;
    }

    function getJotAmountLeft(uint256 tokenId) public view returns (uint256) {
        TokenData storage token = tokens[tokenId];
        return token.sellingSupply - token.soldSupply;
    }

    function getSalePrice(uint256 tokenId, uint256 buyAmount) public view returns (uint256) {
        uint256 amount = (buyAmount * tokens[tokenId].fractionPrices);
        return amount;
    }

    function lockedNFT(uint256 tokenId) public view returns (bool) {
        TokenData storage token = tokens[tokenId];
        return !isVerified(tokenId) || token.ownerSupply == 0;
    }

    /**
     * @notice returns the accrued reward by QuickSwap pool LP for a given fractionalization
     */
    function getAccruedReward(uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].liquidityTokenBalance;
    }

    function isAllowedToFlip(uint256 tokenId) public view returns (bool) {
        return
            ISyntheticNFT(erc721address).exists(tokenId) &&
            block.timestamp - tokens[tokenId].lastFlipTime >= protocol.flippingInterval() && // solhint-disable-line
            IERC20(jotAddress).balanceOf(jotPool) > protocol.flippingAmount() &&
            isSyntheticNFTFractionalised(tokenId);
    }

    function getliquiditySold(uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].liquiditySold;
    }
}
