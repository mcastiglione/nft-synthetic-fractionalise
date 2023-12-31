// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../governance/ProtocolParameters.sol";
import "../Interfaces.sol";
//import "../implementations/SyntheticCollectionManager.sol";
import "../SyntheticProtocolRouter.sol";
import "../libraries/ProtocolConstants.sol";

import {NFTAuction} from "./NFTAuction.sol";

/**
 * @title auctions manager (fabric for auctions)
 * @author priviprotocol
 */
contract AuctionsManager is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    // roles for access control
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant COLLECTION_MANAGER = keccak256("COLLECTION_MANAGER");
    bytes32 public constant AUCTION = keccak256("AUCTION");

    /// @dev the address of the beacon contract for the auctions upgrades
    address private _beacon;

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

    /**
     * @dev the initializer modifier is to avoid someone initializing
     *      the implementation contract after deployment
     */
    constructor() initializer {} // solhint-disable-line

    /**
     * @dev initializes the protocol and router addresses,
     *      sets the UPGRADER_ROLE to governance (only governance can upgrade)
     *
     * @param governance_ the address of the goverance contract (timelock actually)
     * @param protocol_ the address of the protocol parameters contract
     * @param router_ the address of the protocol router contract
     */
    function initialize(
        address governance_,
        address beacon_,
        address protocol_,
        address router_
    ) external initializer {
        protocol = ProtocolParameters(protocol_);
        router = SyntheticProtocolRouter(router_);
        _beacon = beacon_;

        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, router_);
        _setupRole(UPGRADER_ROLE, governance_);
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
        ISyntheticCollectionManager(collection_).reassignNFT(nftId_, newOwner_);
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
        ISyntheticCollectionManager manager = ISyntheticCollectionManager(collection_);

        require(_whitelistedTokens[collection_][nftId_], "Token can't be auctioned");
        require(_recoverableTillDate[collection_][nftId_] < block.timestamp, "Token is yet recoverable"); //solhint-disable-line
        require(openingBid_ >= ProtocolConstants.JOT_SUPPLY, "Opening bid too low");

        address originalCollection = manager.originalCollectionAddress();
        require(router.isNFTVerified(originalCollection, nftId_), "The token should be first verified");

        // blacklist the nft to avoid start a new auction
        _whitelistedTokens[collection_][nftId_] = false;

        address jotToken = router.getJotsAddress(originalCollection);

        // deploy the beacon proxy
        address auctionAddress = address(new BeaconProxy(_beacon, ""));
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

        emit AuctionStarted(collection_, nftId_, auctionAddress, openingBid_);
    }

    // solhint-disable-next-line
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}
