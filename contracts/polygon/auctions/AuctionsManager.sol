// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../governance/ProtocolParameters.sol";
import "../implementations/SyntheticCollectionManager.sol";
import "../SyntheticProtocolRouter.sol";
import "./NFTAuction.sol";

contract AuctionsManager is AccessControl {
    bytes32 private constant COLLECTION_MANAGER = keccak256("COLLECTION_MANAGER");
    bytes32 private constant AUCTION = keccak256("AUCTION");

    ProtocolParameters private _protocol;
    SyntheticProtocolRouter private _router;

    mapping(address => mapping(uint256 => bool)) private _whitelistedTokens;

    event AuctionStarted(
        address indexed collection,
        uint256 indexed nftId,
        address auctionContract,
        uint256 openingBid
    );

    /**
     * @dev the implementation to deploy through minimal proxies
     */
    address private _nftAuctionImplementation;

    constructor(
        address router_,
        address protocol_,
        address nftAuction_
    ) {
        _router = SyntheticProtocolRouter(router_);
        _protocol = ProtocolParameters(protocol_);
        _nftAuctionImplementation = nftAuction_;
    }

    function whitelistNFT(address collection_, uint256 nftId_) external onlyRole(COLLECTION_MANAGER) {
        _whitelistedTokens[collection_][nftId_] = true;
    }

    /**
     * @dev we need to pass the jobSupply here to work well even when the governance
     *      changes this protocol parameter in the middle of the auction
     */
    function reassignNFT(
        address collection_,
        uint256 nftId_,
        address newOwner_,
        uint256 jotsSupply_
    ) external onlyRole(AUCTION) {
        SyntheticCollectionManager(collection_).reassignNFT(nftId_, newOwner_, jotsSupply_);
    }

    function startAuction(
        address collection_,
        uint256 nftId_,
        uint256 openingBid_
    ) external {
        uint256 jotsSupply = _protocol.jotsSupply();
        require(_whitelistedTokens[collection_][nftId_], "Token can't be auctioned");
        require(openingBid_ >= jotsSupply, "Opening bid too low");
        require(_router.isSyntheticNFTCreated(collection_, nftId_), "Non registered token");

        // blacklist the nft to avoid start a new auction
        _whitelistedTokens[collection_][nftId_] = false;

        address jotToken = _router.getJotsAddress(collection_);

        // deploys a minimal proxy contract from privi nft auction implementation
        address auctionAddress = Clones.clone(_nftAuctionImplementation);
        NFTAuction(auctionAddress).initialize(
            nftId_,
            jotToken,
            _router.getJotStakingAddress(collection_),
            _router.getCollectionManagerAddress(collection_),
            jotsSupply,
            openingBid_,
            _protocol.auctionDuration(),
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
