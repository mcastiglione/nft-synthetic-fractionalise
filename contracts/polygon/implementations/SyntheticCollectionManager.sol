// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../libraries/SyntheticTokenLibrary.sol";
import "../extensions/IERC20ManagedAccounts.sol";
import "../chainlink/OracleStructs.sol";
import "../libraries/ProtocolConstants.sol";
import "../governance/ProtocolParameters.sol";
import "../Interfaces.sol";
import "./Jot.sol";
import "./JotPool.sol";
import "./RedemptionPool.sol";
import "./Structs.sol";
import "./Enums.sol";

/**
 * @title synthetic collection abstraction contract
 * @author priviprotocol
 */
contract SyntheticCollectionManager is AccessControl, Initializable {
    using SafeERC20 for IERC20;
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

    /// @notice the address of the auctions manager fabric contract
    address public AuctionsManagerAddress;

    /// @notice the address of the protocol router
    address public syntheticProtocolRouterAddress;

    address private _swapAddress;

    /// @dev mapping the request id from Chainlink with the flip input data
    mapping(bytes32 => Flip) private _flips;

    mapping(uint256 => uint256) private _originalToSynthetic;

    mapping(uint256 => bool) private canFlip;

    address public protocol;

    /// @notice address of the original collection
    address public originalCollectionAddress;

    /// @notice jot Address for this collection
    address public jotAddress;

    /// @notice funding token address
    address public fundingTokenAddress;

    uint256 public buybackPrice;
    uint256 private _buybackPriceLastUpdate;

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

    event BuybackPriceUpdateRequested(bytes32 requestId);
    event BuybackPriceUpdated(bytes32 requestId, uint256 price);

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
        AuctionsManagerAddress = auctionManagerAddress_;
        protocol = protocol_;
        jotPool = jotPool_;
        redemptionPool = redemptionPool_;

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

        TokenData storage token = tokens[nftId_];

        // Get original token ID
        uint256 originalID = token.originalTokenID;

        // Burn synthetic NFT
        ISyntheticNFT(erc721address).safeBurn(nftId_);

        // Mint new one
        uint256 newSyntheticID = ISyntheticNFT(erc721address).safeMint(newOwner_, metadata);

        // Update original to synthetic mapping
        _originalToSynthetic[originalID] = newSyntheticID;

        // Empty previous id
        tokens[nftId_] = TokenData(0, 0, 0, 0, 0, 0, 0, State.NEW);

        // Fill new ID
        tokens[newSyntheticID] = TokenData(
            originalID,
            ProtocolConstants.JOT_SUPPLY,
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

        syntheticId = ISyntheticNFT(erc721address).safeMint(nftOwner_, metadata_);
        uint256 sellingSupply = ProtocolConstants.JOT_SUPPLY - supplyToKeep_;

        TokenData memory data = TokenData({
            originalTokenID: tokenId_,
            ownerSupply: supplyToKeep_,
            sellingSupply: sellingSupply,
            soldSupply: 0,
            liquiditySold: 0,
            fractionPrices: priceFraction_,
            lastFlipTime: 0,
            state: State.NEW
        });

        tokens[syntheticId] = data;

        // lock the nft and make it auctionable
        if (supplyToKeep_ == 0) {
            IAuctionsManager(AuctionsManagerAddress).whitelistNFT(syntheticId);
        }

        canFlip[syntheticId] = true;
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

    function withdrawFundingTokens(uint256 tokenId, uint256 amount) external {
        TokenData storage token = tokens[tokenId];
        require(!lockedNFT(tokenId), "Token is locked!");
        require(isOwner(tokenId, msg.sender), "Only owner can withdraw");

        require(amount <= token.liquiditySold, "Not enough balance");

        IERC20(fundingTokenAddress).transfer(msg.sender, amount);

        token.liquiditySold -= amount;
    }

    /**
     * @notice allows the caller to deposit jots
     * @param tokenId_ the id of the synthetic nft
     * @param amountToDeposit_ the amount of jots to deposit
     */
    function depositJotTokens(uint256 tokenId_, uint256 amountToDeposit_) external {
        TokenData storage token = tokens[tokenId_];
        require(isOwner(tokenId_, msg.sender), "Only owner can deposit");

        token.depositJotTokens(amountToDeposit_);

        // transfer the balance (the Jot is ours, don't need to check)
        IJot(jotAddress).transferFrom(msg.sender, address(this), amountToDeposit_);
    }

    function withdrawJotTokens(uint256 tokenId_, uint256 amountToWithdraw_) public {
        TokenData storage token = tokens[tokenId_];
        require(!lockedNFT(tokenId_), "Token is locked!");
        require(isOwner(tokenId_, msg.sender), "Only owner can withdraw");

        require(amountToWithdraw_ <= token.ownerSupply, "Not enough balance");
        token.ownerSupply -= amountToWithdraw_;

        IJot(jotAddress).transfer(msg.sender, amountToWithdraw_);
        if (token.ownerSupply == 0) {
            IAuctionsManager(AuctionsManagerAddress).whitelistNFT(tokenId_);
        }
    }

    /**
     * @notice increase selling supply for a given NFT
     * @dev caller must be the owner of the NFT
     * @param tokenId_ the id of the synthetic nft
     * @param amount_ the amount of jots to transfer from supply
     */
    function increaseSellingSupply(uint256 tokenId_, uint256 amount_) public {
        require(ISyntheticNFT(erc721address).ownerOf(tokenId_) == msg.sender, "Only owner can increase");

        // delegate to the external library
        tokens[tokenId_].increaseSellingSupply(amount_);

        // lock the nft and make it auctionable
        if (tokens[tokenId_].ownerSupply == 0) {
            IAuctionsManager(AuctionsManagerAddress).whitelistNFT(tokenId_);
        }
    }

    /**
     * @notice decrease selling supply for a given NFT
     * @dev caller must be the owner of the NFT
     * @param tokenId_ the id of the synthetic nft
     * @param amount_ the amount of jots to transfer to supply
     */
    function decreaseSellingSupply(uint256 tokenId_, uint256 amount_) public {
        require(ISyntheticNFT(erc721address).ownerOf(tokenId_) == msg.sender, "Only owner allowed");

        tokens[tokenId_].decreaseSellingSupply(amount_);
    }

    /**
     * @notice update the price of a fraction for a given NFT
     * @dev caller must be the owner of the NFT
     * @param tokenId_ the id of the synthetic nft
     * @param newFractionPrice_ the new value of the fraction price
     */
    function updatePriceFraction(uint256 tokenId_, uint256 newFractionPrice_) public {
        require(ISyntheticNFT(erc721address).ownerOf(tokenId_) == msg.sender, "Only owner allowed");
        tokens[tokenId_].updatePriceFraction(newFractionPrice_);
    }

    function flipJot(uint256 tokenId, uint64 prediction) external {
        
        TokenData storage token = tokens[tokenId];

        require(isAllowedToFlip(tokenId), "Flip is not allowed yet");
        require(!lockedNFT(tokenId), "Token is locked!");

        token.lastFlipTime = block.timestamp; // solhint-disable-line

        bytes32 requestId = IRandomNumberConsumer(_randomConsumerAddress).getRandomNumber();
        _flips[requestId] = Flip({tokenId: tokenId, prediction: prediction, player: msg.sender});

        emit CoinFlipped(requestId, msg.sender, tokenId, prediction);
        
    }

    function processFlipResult(uint256 randomNumber, bytes32 requestId) external onlyRole(RANDOM_ORACLE) {
        
        uint256 poolAmount;
        uint256 fAmount = ProtocolParameters(protocol).flippingAmount();
        uint256 fReward = ProtocolParameters(protocol).flippingReward();

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
            IAuctionsManager(AuctionsManagerAddress).whitelistNFT(flip.tokenId);
        }

        emit FlipProcessed(requestId, flip.tokenId, flip.prediction, randomNumber);
    }

    function recoverToken(uint256 tokenId) external {
        require(IAuctionsManager(AuctionsManagerAddress).isRecoverable(tokenId), "Token is not recoverable");
        require(isOwner(tokenId, msg.sender), "Only owner allowed");

        // reverts on failure
        IERC20(jotAddress).safeTransferFrom(msg.sender, address(this), ProtocolConstants.JOT_SUPPLY);

        tokens[tokenId].ownerSupply = ProtocolConstants.JOT_SUPPLY;

        IAuctionsManager(AuctionsManagerAddress).blacklistNFT(tokenId);
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

        bytes32 requestId = IPolygonValidatorOracle(_validatorAddress).verifyTokenInCollection(
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
     * @notice allows users to update buyback price for buyback
     */
    function updateBuybackPrice() external returns (bytes32 requestId) {
        requestId = IPolygonValidatorOracle(_validatorAddress).updateBuybackPrice(originalCollectionAddress);

        emit BuybackPriceUpdateRequested(requestId);
    }

    /**
     * @dev processes the oracle response for buyback price updates
     * @param requestId_ the id of the Chainlink request
     * @param buybackPrice_ the new buyback price
     */
    function processBuybackPriceResponse(bytes32 requestId_, uint256 buybackPrice_)
        external
        onlyRole(VALIDATOR_ORACLE)
    {
        buybackPrice = buybackPrice_;
        _buybackPriceLastUpdate = block.timestamp; // solhint-disable-line

        emit BuybackPriceUpdated(requestId_, buybackPrice_);
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

        (jotsLeft, fundingLeft, buybackAmount) = getFundingLeftAndBuybackAmount(tokenId);
    }

    /**
     * @notice Buy token back.
     * Caller needs to pre-approve a transaction worth the amount
     * returned by the getRequiredFundingForBuyback(uint256 tokenId) function
     */
    function buyback(uint256 tokenId) public {
        // solhint-disable-next-line
        require(block.timestamp < _buybackPriceLastUpdate + 5 minutes, "Buyback price update required");
        require(isOwner(tokenId, msg.sender), "Only owner allowed");
        require(!lockedNFT(tokenId), "Token is locked!");

        // execute the buyback if needed and remove the liquidity
        _executeBuyback(tokenId);

        // exit the protocol
        _exitProtocol(tokenId);
    }

    /**
     * @dev helper for the execute buyback function
     */
    function getFundingLeftAndBuybackAmount(uint256 tokenId)
        public
        view
        returns (
            uint256 jotsLeft,
            uint256 fundingLeft,
            uint256 buybackAmount
        )
    {

        TokenData storage token = tokens[tokenId];

        // Total available Jots is owner supply + selling supply
        uint256 total = token.ownerSupply + token.sellingSupply;

        // Starting funding left
        fundingLeft = token.liquiditySold;

        // If user has more jots than needed for buyback, then jotsLeft = leftover
        // If user has less jots than needed for buyback, then buybackAmount = jots needed for buyback 
        if (total >= ProtocolConstants.JOT_SUPPLY) {
            jotsLeft = total - ProtocolConstants.JOT_SUPPLY;
        } else {
            // how much funding is needed for buyback
            buybackAmount = ((ProtocolConstants.JOT_SUPPLY - total) * buybackPrice) / 10**18;

            // if the user has funding tokens available...
            if (fundingLeft > 0) {
                // If user has enough, then save remaining for sending later
                if (fundingLeft >= buybackAmount) {
                    fundingLeft -= buybackAmount;
                // If user doesn't have enough, then subtract available funding from required amount
                } else {
                    buybackAmount -= fundingLeft;
                }
            }
        }
    }

    /**
     * @dev helper for the buyback function
     */
    function _executeBuyback(uint256 tokenId) internal {
        TokenData storage token = tokens[tokenId];

        // Total available Jots is owner suppl y selling supply
        uint256 total = token.ownerSupply + token.sellingSupply;

        (uint256 jotsLeft, uint256 fundingLeft, uint256 buybackAmount) = getFundingLeftAndBuybackAmount(tokenId);

        // If the user has less jots than needed for buyback, burn all of them
        // If the user more jots than needed for buyback, then burn JOTS_SUPPLY and send remaining
        uint256 burned = total < ProtocolConstants.JOT_SUPPLY ? total : ProtocolConstants.JOT_SUPPLY;

        // burn the jots
        Jot(jotAddress).burn(burned);

        if (buybackAmount > 0) {
            // increase allowance to burn
            Jot(jotAddress).increaseAllowance(redemptionPool, ProtocolConstants.JOT_SUPPLY - burned);

            // update redemption pool balance trackers
            RedemptionPool(redemptionPool).addRedemableBalance(buybackAmount, (buybackAmount / buybackPrice * 10**18));

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
        require(!lockedNFT(tokenId), "Token is locked!");
        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(_swapAddress);
        address[] memory path = new address[](2);
        path[0] = jotAddress;
        path[1] = fundingTokenAddress;

        tokens[tokenId].ownerSupply -= amount;
        if (tokens[tokenId].ownerSupply == 0) {
            IAuctionsManager(AuctionsManagerAddress).whitelistNFT(tokenId);
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

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /*function isVerified(uint256 tokenId) public view returns (bool) {
        return (tokens[tokenId].state == State.VERIFIED);
    }*/

    /*function getOriginalID(uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].originalTokenID;
    }*/

    /*function getTokenURI(uint256 tokenId) public view returns (string memory) {
        return ISyntheticNFT(erc721address).tokenURI(tokenId);
    }*/

    /**
     * @notice get the owner of the NFT
     * @param tokenId_ the id of the NFT
     */
    /*function getSyntheticNFTOwner(uint256 tokenId_) public view returns (address) {
        return IERC721(erc721address).ownerOf(tokenId_);
    }*/

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

    /*function getOwnerSupply(uint256 tokenId) public view returns (uint256) {
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
    }*/

    /*function getJotAmountLeft(uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].sellingSupply;
    }*/

    function getSalePrice(uint256 tokenId, uint256 buyAmount) public view returns (uint256) {
        uint256 amount = (buyAmount * tokens[tokenId].fractionPrices);
        return amount;
    }

    function lockedNFT(uint256 tokenId) public view returns (bool) {
        TokenData storage token = tokens[tokenId];
        return token.state != State.VERIFIED || token.ownerSupply == 0;
    }

    function isAllowedToFlip(uint256 tokenId) public view returns (bool) {
        return
            canFlip[tokenId] &&
            ISyntheticNFT(erc721address).exists(tokenId) &&
            block.timestamp - tokens[tokenId].lastFlipTime >= ProtocolParameters(protocol).flippingInterval() && // solhint-disable-line
            IERC20(jotAddress).balanceOf(jotPool) > ProtocolParameters(protocol).flippingAmount() &&
            isSyntheticNFTFractionalised(tokenId);
    }

    /*function getliquiditySold(uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].liquiditySold;
    }

    function getLiquidityTokens(uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].liquidityTokenBalance;
    }*/

    function isOwner(uint256 tokenId, address caller) public view returns (bool) {
        return ISyntheticNFT(erc721address).ownerOf(tokenId) == caller;
    }

    function setFlip(uint256 tokenId, bool value) public {
        require(isOwner(tokenId, msg.sender), "Only owner can change flip");
        canFlip[tokenId] = value;
    }

    /*function getLtoken(uint256 tokenId) public view returns (uint256) {
        return tokens[tokenId].perpetualFuturesLShares;
    }*/
}
