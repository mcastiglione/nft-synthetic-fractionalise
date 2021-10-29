// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./LiquidityCalculator.sol";
import "../libraries/SyntheticTokenLibrary.sol";
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
//import "hardhat/console.sol";

import {AuctionsManager} from "../auctions/AuctionsManager.sol";

/**
 * @title synthetic collection abstraction contract
 * @author priviprotocol
 */
contract SyntheticCollectionManager is AccessControl, Initializable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    using SyntheticTokenLibrary for TokenData;

    /// @notice role of the router contract
    bytes32 public constant ROUTER = keccak256("ROUTER");

    /// @notice role of the auctions manager fabric contract
    bytes32 public constant AUCTION_MANAGER = keccak256("AUCTION_MANAGER");

    /// @notice role of the vrf chainlink oracle
    bytes32 public constant RANDOM_ORACLE = keccak256("RANDOM_ORACLE");

    /// @notice role of the polygon validator chainlink oracle for verifications
    bytes32 public constant VALIDATOR_ORACLE = keccak256("VALIDATOR_ORACLE");

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

    address private _liquidityCalculatorAddress;

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

    uint256 public buybackPrice;

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
        address swapAddress_,
        address liquidityCalculatorAddress_
    ) external initializer {
        jotAddress = jotAddress_;
        erc721address = erc721address_;
        originalCollectionAddress = originalCollectionAddress_;
        syntheticProtocolRouterAddress = msg.sender;
        auctionsManagerAddress = auctionManagerAddress_;
        protocol = ProtocolParameters(protocol_);
        jotPool = jotPool_;
        redemptionPool = redemptionPool_;

        _swapAddress = swapAddress_;

        _liquidityCalculatorAddress = liquidityCalculatorAddress_;

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

        TokenData storage token = tokens[nftId_];

        // Get original token ID
        uint256 originalID = token.originalTokenID;

        // Burn synthetic NFT
        ISyntheticNFT(erc721address).safeBurn(nftId_);

        // Get new synthetic ID
        uint256 newSyntheticID = tokenCounter.current();
        tokenCounter.increment();

        // Mint new one
        ISyntheticNFT(erc721address).safeMint(newOwner_, newSyntheticID, metadata);

        // Update original to synthetic mapping
        _originalToSynthetic[originalID] = newSyntheticID;

        // Empty previous id
        tokens[nftId_] = TokenData(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, State.NEW);

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
            0,
            State.VERIFIED
        );

        emit TokenReassigned(newSyntheticID, newOwner_);
    }

    /**
     * @dev through this the router can register tokens
     * @param tokenId_ the original token id
     * @param supplyToKeep_ the supply that the owner decides to keep
     * @param priceFraction_ the price fraction for buying
     * @param nftOwner_ the owner of the synthetic nft
     * @param metadata_ the metadata (the ipfs url) of the nft
     * @return syntheticId the id of the newly registered token
     */
    function register(
        uint256 tokenId_,
        uint256 supplyToKeep_,
        uint256 priceFraction_,
        address nftOwner_,
        string memory metadata_
    ) public onlyRole(ROUTER) returns (uint256 syntheticId) {
        require(!isSyntheticNFTCreated(tokenId_), "Synthetic NFT already generated!");

        syntheticId = tokenCounter.current();
        tokenCounter.increment();

        ISyntheticNFT(erc721address).safeMint(nftOwner_, syntheticId, metadata_);

        uint256 sellingSupply = (ProtocolConstants.JOT_SUPPLY - supplyToKeep_) / 2;
        uint256 liquiditySupply = (ProtocolConstants.JOT_SUPPLY - supplyToKeep_) / 2;

        TokenData memory data = TokenData({
            originalTokenID: tokenId_,
            ownerSupply: supplyToKeep_,
            sellingSupply: sellingSupply,
            soldSupply: 0,
            liquiditySupply: liquiditySupply,
            liquiditySold: 0,
            fractionPrices: priceFraction_,
            lastFlipTime: 0,
            liquidityTokenBalance: 0,
            uniswapJotLiquidity: 0,
            uniswapFundingLiquidity: 0,
            perpetualFuturesLShares: 0,
            state: State.NEW
        });

        tokens[syntheticId] = data;

        // lock the nft and make it auctionable
        if (supplyToKeep_ == 0) {
            AuctionsManager(auctionsManagerAddress).whitelistNFT(syntheticId);
        }
    }

    /**
     * @notice allows the caller to buy jots using the funding token
     * @param tokenId_ the id of the synthetic nft
     * @param amountToBuy_ the amount of jots to buy
     */
    function buyJotTokens(uint256 tokenId_, uint256 amountToBuy_) external {
        TokenData storage token = tokens[tokenId_];
        require(ISyntheticNFT(erc721address).exists(tokenId_), "Token not registered");

        uint256 amountToPay = token.buyJotTokens(amountToBuy_);

        // make the transfers
        IERC20(fundingTokenAddress).transferFrom(msg.sender, address(this), amountToPay);
        IJot(jotAddress).transfer(msg.sender, amountToBuy_);
    }

    /**
     * @notice allows the caller to deposit jots
     * @param tokenId_ the id of the synthetic nft
     * @param amountToDeposit_ the amount of jots to deposit
     */
    function depositJotTokens(uint256 tokenId_, uint256 amountToDeposit_) external {
        TokenData storage token = tokens[tokenId_];
        require(ISyntheticNFT(erc721address).ownerOf(tokenId_) == msg.sender, "Only owner can deposit");

        token.depositJotTokens(amountToDeposit_);

        // transfer the balance (the Jot is ours, don't need to check)
        IJot(jotAddress).transferFrom(msg.sender, address(this), amountToDeposit_);
    }

    function withdrawJotTokens(uint256 tokenId_, uint256 amountToWithdraw_) public {
        TokenData storage token = tokens[tokenId_];
        require(!lockedNFT(tokenId_), "Token is locked!");
        require(ISyntheticNFT(erc721address).ownerOf(tokenId_) == msg.sender, "Only owner can withdraw");

        require(amountToWithdraw_ <= token.ownerSupply, "Not enough balance");
        token.ownerSupply -= amountToWithdraw_;

        IJot(jotAddress).transfer(msg.sender, amountToWithdraw_);
        if (token.ownerSupply == 0) {
            AuctionsManager(auctionsManagerAddress).whitelistNFT(tokenId_);
        }
    }

    /**
     * @notice increase selling supply for a given NFT
     * @dev caller must be the owner of the NFT
     * @param tokenId_ the id of the synthetic nft
     * @param amount_ the amount of jots to transfer from supply
     */
    function increaseSellingSupply(uint256 tokenId_, uint256 amount_) public {
        TokenData storage token = tokens[tokenId_];
        require(ISyntheticNFT(erc721address).ownerOf(tokenId_) == msg.sender, "Only owner can increase");

        // delegate to the external library
        token.increaseSellingSupply(amount_);

        // lock the nft and make it auctionable
        if (token.ownerSupply == 0) {
            AuctionsManager(auctionsManagerAddress).whitelistNFT(tokenId_);
        }
    }

    /**
     * @notice decrease selling supply for a given NFT
     * @dev caller must be the owner of the NFT
     * @param tokenId_ the id of the synthetic nft
     * @param amount_ the amount of jots to transfer to supply
     */
    function decreaseSellingSupply(uint256 tokenId_, uint256 amount_) public {
        TokenData storage token = tokens[tokenId_];

        require(ISyntheticNFT(erc721address).ownerOf(tokenId_) == msg.sender, "Only owner allowed");

        token.decreaseSellingSupply(amount_);
    }

    /**
     * @notice update the price of a fraction for a given NFT
     * @dev caller must be the owner of the NFT
     * @param tokenId_ the id of the synthetic nft
     * @param newFractionPrice_ the new value of the fraction price
     */
    function updatePriceFraction(uint256 tokenId_, uint256 newFractionPrice_) public {
        TokenData storage token = tokens[tokenId_];
        require(ISyntheticNFT(erc721address).ownerOf(tokenId_) == msg.sender, "Only owner allowed");

        token.updatePriceFraction(newFractionPrice_);
    }

    /**
     * @notice add available liquidity to Perpetual Pool
     */
    function addLiquidityToPerpetualPool(uint256 tokenId) public {
        TokenData storage token = tokens[tokenId];
        uint256 perpetualFundingLiquidity = LiquidityCalculator(_liquidityCalculatorAddress)
            .getAvailableFundingPerpetual(token);
        if (perpetualFundingLiquidity > 0) {
            IERC20(fundingTokenAddress).approve(_perpetualPoolLiteAddress, perpetualFundingLiquidity);
            uint256 lShares = IPerpetualPoolLite(_perpetualPoolLiteAddress).addLiquidityGetlShares(
                perpetualFundingLiquidity
            );
            tokens[tokenId].soldSupply - perpetualFundingLiquidity;
            tokens[tokenId].perpetualFuturesLShares += lShares;
        }
    }

    /**
     * @notice add available liquidity for a given token to UniSwap pool
     */
    function addLiquidityToPool(uint256 tokenId) public {
        TokenData storage token = tokens[tokenId];

        require(token.soldSupply > 0, "soldSupply is zero");

        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(_swapAddress);

        (uint256 jotsValue, uint256 fundingValue, uint256 remainingJots) = LiquidityCalculator(
            _liquidityCalculatorAddress
        ).getAvailableFundingUniswap(token);

        // Approve Uniswap address
        IJot(jotAddress).approve(_swapAddress, jotsValue);
        IERC20(fundingTokenAddress).approve(_swapAddress, fundingValue);

        // add the liquidity to Uniswapp
        (uint256 amountA, uint256 amountB, uint256 liquidity) = uniswapV2Router.addLiquidity(
            jotAddress,
            fundingTokenAddress,
            jotsValue,
            fundingValue,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp // solhint-disable-line
        );
        // If there is a remaining, add as liquidity to PerpetualPool
        if (amountB < fundingValue) {
            uint256 fundingRemaining = fundingValue - amountB;

            IERC20(fundingTokenAddress).approve(_perpetualPoolLiteAddress, fundingRemaining);

            IPerpetualPoolLite(_perpetualPoolLiteAddress).addLiquidity(fundingRemaining);
        }

        // Update balances
        token.liquiditySupply -= (amountA + remainingJots);
        token.liquiditySold -= fundingValue;
        token.sellingSupply -= amountA;
        token.sellingSupply += remainingJots;
        token.soldSupply -= fundingValue;
        token.liquidityTokenBalance += liquidity;
        token.uniswapJotLiquidity += amountA;
        token.uniswapFundingLiquidity += amountB;

        addLiquidityToPerpetualPool(tokenId);
    }

    /**
     * @dev remove liquidity from pool only callable by AuctionsManager
     */
    function removeLiquidityFromPool(uint256 tokenId) external onlyRole(AUCTION_MANAGER) {
        address tokenOwner = ISyntheticNFT(erc721address).ownerOf(tokenId);

        (uint256 jotLiquidity, uint256 fundingLiquidity) = _removeLiquidityFromPool(tokenId);
        tokens[tokenId].ownerSupply += jotLiquidity;

        // transfer funding token balance to caller
        IERC20(fundingTokenAddress).transfer(tokenOwner, fundingLiquidity);

        if (tokens[tokenId].perpetualFuturesLShares != 0) {
            IPerpetualPoolLite(_perpetualPoolLiteAddress).removeLiquidity(
                tokens[tokenId].perpetualFuturesLShares
            );
        }
    }

    /**
     * @dev remove liquidity from Pool
     */
    function _removeLiquidityFromPool(uint256 tokenId) internal returns (uint256, uint256) {
        TokenData storage token = tokens[tokenId];

        IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(poolAddress());

        // get added liquidity
        uint256 jotLiquidity = token.uniswapJotLiquidity;
        uint256 fundingLiquidity = token.uniswapFundingLiquidity;
        uint256 liquidityTokenBalance = token.liquidityTokenBalance;

        if (liquidityTokenBalance == 0 || jotLiquidity == 0 || fundingLiquidity == 0) {
            return (0, 0);
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
            if (randomNumber != flip.prediction) {
                poolAmount = fAmount;
            } else {
                poolAmount = fAmount - fReward;
                IERC20ManagedAccounts(jotAddress).transferFromManaged(
                    jotPool,
                    _flips[requestId].player,
                    fReward
                );
            }
            if (poolAmount > 0) {
                token.ownerSupply += poolAmount;
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
     * @notice this method calls chainlink oracle and
     *         verifies if the NFT has been locked on NFTVaultManager. In addition
     *         gets the metadata of the NFT
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

            // mint the jots after verification
            Jot(jotAddress).mint(address(this), ProtocolConstants.JOT_SUPPLY);
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

        // caller must be token owner
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

        IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(poolAddress());

        uint256 liquidity = token.liquidityTokenBalance;

        (uint112 jotReserves, uint112 fundingReserves, ) = uniswapV2Pair.getReserves();

        uint256 totalSupply = uniswapV2Pair.totalSupply();

        uint256 jotLiquidity;

        if (totalSupply > 0) {
            jotLiquidity = (liquidity * jotReserves) / totalSupply;
            // the funding liquidity is the total funding
            totalFunding = (liquidity * fundingReserves) / totalSupply;
        } else {
            totalFunding = fundingReserves;
        }

        totalJots = token.ownerSupply + token.sellingSupply + token.liquiditySupply + jotLiquidity;
    }

    function buybackRequiredAmount(uint256 tokenId)
        public
        view
        returns (
            uint256 buybackAmount,
            uint256 fundingLeft,
            uint256 jotsLeft
        )
    {
        require(!lockedNFT(tokenId), "Token is locked!");

        (uint256 total, uint256 fundingLiquidity) = getAvailableJotsForBuyback(tokenId);

        (jotsLeft, fundingLeft, buybackAmount) = _getFundingLeftAndBuybackAmount(total, fundingLiquidity);
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

        (uint256 jotsLeft, uint256 fundingLeft, uint256 buybackAmount) = _getFundingLeftAndBuybackAmount(
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

        if (jotsLeft > 0) {
            IJot(jotAddress).transfer(msg.sender, jotsLeft);
        }
    }

    /**
     * @dev helper for the execute buyback function
     */
    function _getFundingLeftAndBuybackAmount(uint256 total_, uint256 fundingLiquidity_)
        internal
        view
        returns (
            uint256 jotsLeft,
            uint256 fundingLeft,
            uint256 buybackAmount
        )
    {
        // Starting funding left
        fundingLeft = fundingLiquidity_;

        // If owner has enough balance buybackAmount is zero
        if (ProtocolConstants.JOT_SUPPLY < total_) {
            buybackAmount = 0;
            jotsLeft = total_ - ProtocolConstants.JOT_SUPPLY;
        } else {
            // If owner has some funding tokens left
            if (fundingLeft > 0) {
                // How many jots you can buy with the funding tokens
                uint256 fundingToJots = (fundingLeft * buybackPrice) / 10**18;
                // if there's enough funding for buyback
                // then return 0 as buybackAmount and the remaining funding
                if ((fundingToJots + total_) > ProtocolConstants.JOT_SUPPLY) {
                    uint256 remainingJots = total_ - ProtocolConstants.JOT_SUPPLY;
                    uint256 requiredFunding = (remainingJots * buybackPrice) / 10**18;
                    fundingLeft -= requiredFunding;
                    buybackAmount = 0;
                }
                // if there isn't enough funding for buyback
                else {
                    buybackAmount = (ProtocolConstants.JOT_SUPPLY - total_ - fundingToJots);
                    fundingLeft = 0;
                }
            } else {
                buybackAmount = ((ProtocolConstants.JOT_SUPPLY - total_) * buybackPrice) / 10**18;
            }
        }
    }

    /**
     * @dev allows to exit the protocol (retrieve the token)
     */
    function _exitProtocol(uint256 tokenId) internal {
        TokenData storage token = tokens[tokenId];

        // increase nonce to avoid double verification
        uint256 currentNonce = nonces[token.originalTokenID];
        ownersByNonce[token.originalTokenID][currentNonce] = msg.sender;
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
     * @notice get the owner of the NFT
     * @param tokenId_ the id of the NFT
     */
    function getSyntheticNFTOwner(uint256 tokenId_) public view returns (address) {
        return IERC721(erc721address).ownerOf(tokenId_);
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
        return token.state != State.VERIFIED || token.ownerSupply == 0;
    }

    /**
     * @notice returns the accrued reward by QuickSwap pool LP for a given fractionalization
     */
    function getAccruedReward(uint256 tokenId) public view returns (uint256, uint256) {
        return
            LiquidityCalculator(_liquidityCalculatorAddress).getAccruedReward(
                poolAddress(),
                tokens[tokenId].liquidityTokenBalance
            );
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
