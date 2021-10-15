// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../governance/ProtocolParameters.sol";
import "../implementations/SyntheticCollectionManager.sol";
import "../SyntheticProtocolRouter.sol";
import "../libraries/ProtocolConstants.sol";
import "./NFTAuction.sol";

/**
 * @title auctions manager (fabric for auctions)
 * @author priviprotocol
 */
contract AuctionsManager is AccessControl, Initializable {
    // roles for access control
    bytes32 public constant COLLECTION_MANAGER = keccak256("COLLECTION_MANAGER");
    bytes32 public constant DEPLOYER = keccak256("DEPLOYER");
    bytes32 public constant AUCTION = keccak256("AUCTION");

    /// @dev the implementation to deploy through minimal proxies
    address private immutable _nftAuctionImplementation;

    /// @notice the address of the protocol parameters controlled by goverance
    ProtocolParameters public protocol;

    /// @notice the address of the protocol router
    SyntheticProtocolRouter public router;

    /**
     * @dev auctionable tokens at the moment
     *      collection => tokenId => isWhitelisted
     */
    mapping(address => mapping(uint256 => bool)) private _whitelistedTokens;

    /**
     * @dev timestamp in seconds for a token recoverable date limit
     *      collection => tokenId => timestamp
     */
    mapping(address => mapping(uint256 => uint256)) private _recoverableTillDate;

    /**
     * @dev emitted when an auction is launched with an initial bid
     * @param collection the address of the synthetic nft collection
     * @param nftId the id of the synthetic nft token
     * @param auctionContract the address of the new deployed auction
     * @param openingBid the value of the opening bid
     */
    event AuctionStarted(
        address indexed collection,
        uint256 indexed nftId,
        address auctionContract,
        uint256 openingBid
    );

    /// @param nftAuction_ the address of the auction contract implementation
    constructor(address nftAuction_) {
        _nftAuctionImplementation = nftAuction_;

        _setupRole(DEPLOYER, msg.sender);
    }

    /**
     * @dev initializes the protocol and router addresses
     * @param protocol_ the address of the protocol parameters contract
     * @param router_ the address of the protocol router contract
     */
    function initialize(address protocol_, address router_) external initializer onlyRole(DEPLOYER) {
        protocol = ProtocolParameters(protocol_);
        router = SyntheticProtocolRouter(router_);

        _setupRole(DEFAULT_ADMIN_ROLE, router_);
    }

    /**
     * @dev makes a nft auctionable (callable only by a synthetic collection manager)
     * @param nftId_ the id of the synthetic nft token
     */
    function whitelistNFT(uint256 nftId_) external onlyRole(COLLECTION_MANAGER) {
        _whitelistedTokens[msg.sender][nftId_] = true;
        _recoverableTillDate[msg.sender][nftId_] = block.timestamp + protocol.recoveryThreshold(); // solhint-disable-line
    }

    /**
     * @dev makes a nft non auctionable (callable only by a synthetic collection manager)
     * @param nftId_ the id of the synthetic nft token
     */
    function blacklistNFT(uint256 nftId_) external onlyRole(COLLECTION_MANAGER) {
        _whitelistedTokens[msg.sender][nftId_] = false;
    }

    /**
     * @notice check if a nft is yet recoverable
     * @param nftId_ the id of the synthetic nft token
     */
    function isRecoverable(uint256 nftId_) public view returns (bool) {
        return (_whitelistedTokens[msg.sender][nftId_] &&
            _recoverableTillDate[msg.sender][nftId_] >= block.timestamp); // solhint-disable-line
    }

    /**
     * @notice check when an auctionable nft would be recoverable until
     * @param manager_ the address of the synthetic collection manager
     * @param nftId_ the id of the synthetic nft token
     */
    function isRecoverableTill(address manager_, uint256 nftId_) public view returns (uint256) {
        return _recoverableTillDate[manager_][nftId_];
    }

    /**
     * @dev reassigns the nft to the new owner (callable only by an auction)
     * @param collection_ the address of the synthetic collection manager
     * @param nftId_ the id of the synthetic nft token
     * @param newOwner_ the winner of the auction
     */
    function reassignNFT(
        address collection_,
        uint256 nftId_,
        address newOwner_
    ) external virtual onlyRole(AUCTION) {
        SyntheticCollectionManager(collection_).reassignNFT(nftId_, newOwner_);
    }

    /**
     * @notice allows to start an auction over an auctionable nft which is
     *         already no recoverable
     *
     * @param collection_ the address of the synthetic collection manager
     * @param nftId_ the id of the synthetic nft token
     * @param openingBid_ the opening bid of the auction
     */
    function startAuction(
        address collection_,
        uint256 nftId_,
        uint256 openingBid_
    ) external {
        SyntheticCollectionManager manager = SyntheticCollectionManager(collection_);

        require(_whitelistedTokens[collection_][nftId_], "Token can't be auctioned");
        require(_recoverableTillDate[collection_][nftId_] < block.timestamp, "Token is yet recoverable"); //solhint-disable-line
        require(openingBid_ >= ProtocolConstants.JOT_SUPPLY, "Opening bid too low");
        require(manager.isVerified(nftId_), "The token should be first verified");

        // blacklist the nft to avoid start a new auction
        _whitelistedTokens[collection_][nftId_] = false;

        address originalCollection = manager.originalCollectionAddress();
        address jotToken = router.getJotsAddress(originalCollection);

        // deploys a minimal proxy contract from privi nft auction implementation
        address auctionAddress = Clones.clone(_nftAuctionImplementation);
        NFTAuction(auctionAddress).initialize(
            nftId_,
            jotToken,
            router.getJotPoolAddress(originalCollection),
            router.getCollectionManagerAddress(originalCollection),
            openingBid_,
            protocol.auctionDuration(),
            msg.sender
        );

        // give the AUCTION role to allow blacklisting
        _setupRole(AUCTION, auctionAddress);

        // transfer funds to the auction contract
        require(
            IERC20(jotToken).transferFrom(msg.sender, auctionAddress, openingBid_),
            "Unable to transfer jots"
        );

        manager.removeLiquidityFromPool(nftId_);

        emit AuctionStarted(collection_, nftId_, auctionAddress, openingBid_);
    }
}
