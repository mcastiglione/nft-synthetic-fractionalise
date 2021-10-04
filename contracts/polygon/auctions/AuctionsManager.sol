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

contract AuctionsManager is AccessControl, Initializable {
    bytes32 public constant COLLECTION_MANAGER = keccak256("COLLECTION_MANAGER");
    bytes32 public constant DEPLOYER = keccak256("DEPLOYER");
    bytes32 public constant AUCTION = keccak256("AUCTION");

    /**
     * @dev the implementation to deploy through minimal proxies
     */
    address private immutable _nftAuctionImplementation;

    ProtocolParameters public protocol;
    SyntheticProtocolRouter public router;

    mapping(address => mapping(uint256 => bool)) private _whitelistedTokens;
    mapping(address => mapping(uint256 => uint256)) private _recoverableTillDate;

    event AuctionStarted(
        address indexed collection,
        uint256 indexed nftId,
        address auctionContract,
        uint256 openingBid
    );

    constructor(address nftAuction_) {
        _nftAuctionImplementation = nftAuction_;

        _setupRole(DEPLOYER, msg.sender);
    }

    function initialize(address protocol_, address router_) external initializer onlyRole(DEPLOYER) {
        protocol = ProtocolParameters(protocol_);
        router = SyntheticProtocolRouter(router_);

        _setupRole(DEFAULT_ADMIN_ROLE, router_);
    }

    function whitelistNFT(uint256 nftId_) external onlyRole(COLLECTION_MANAGER) {
        _whitelistedTokens[msg.sender][nftId_] = true;
        _recoverableTillDate[msg.sender][nftId_] = block.timestamp + protocol.recoveryThreshold(); // solhint-disable-line
    }

    function blacklistNFT(uint256 nftId_) external onlyRole(COLLECTION_MANAGER) {
        _whitelistedTokens[msg.sender][nftId_] = false;
    }

    function isRecoverable(uint256 nftId_) public view returns (bool) {
        return (_whitelistedTokens[msg.sender][nftId_] &&
            _recoverableTillDate[msg.sender][nftId_] >= block.timestamp); // solhint-disable-line
    }

    function isRecoverableTill(address manager, uint256 nftId_) public view returns (uint256) {
        return _recoverableTillDate[manager][nftId_];
    }

    function reassignNFT(
        address collection_,
        uint256 nftId_,
        address newOwner_
    ) external onlyRole(AUCTION) {
        SyntheticCollectionManager(collection_).reassignNFT(nftId_, newOwner_);
    }

    function startAuction(
        address collection_,
        uint256 nftId_,
        uint256 openingBid_
    ) external {
        require(_whitelistedTokens[collection_][nftId_], "Token can't be auctioned");
        require(_recoverableTillDate[msg.sender][nftId_] < block.timestamp, "Token is yet recoverable"); //solhint-disable-line
        require(openingBid_ >= ProtocolConstants.JOT_SUPPLY, "Opening bid too low");

        // blacklist the nft to avoid start a new auction
        _whitelistedTokens[collection_][nftId_] = false;

        address jotToken = router.getJotsAddress(collection_);

        // deploys a minimal proxy contract from privi nft auction implementation
        address auctionAddress = Clones.clone(_nftAuctionImplementation);
        NFTAuction(auctionAddress).initialize(
            nftId_,
            jotToken,
            router.getJotPoolAddress(collection_),
            router.getCollectionManagerAddress(collection_),
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
}
