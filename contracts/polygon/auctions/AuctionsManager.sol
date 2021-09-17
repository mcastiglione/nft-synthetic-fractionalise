// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "../governance/ProtocolParameters.sol";
import "../SyntheticProtocolRouter.sol";
import "./NFTAuction.sol";

contract AuctionsManager {
    ProtocolParameters private _protocol;
    SyntheticProtocolRouter private _router;

    event AuctionStarted(address indexed starter, uint256 openingBid);

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

    function startAuction(
        address collection_,
        uint256 nftId_,
        uint256 _openingBid
    ) external {
        require(_openingBid >= _protocol.jotsSupply(), "Opening bid too low");
        require(_router.isSyntheticNFTCreated(collection_, nftId_), "Non registered token");

        // deploys a minimal proxy contract from privi nft auction implementation
        address auctionAddress = Clones.clone(_nftAuctionImplementation);
        NFTAuction(auctionAddress).initialize(
            _router.getJotsAddress(collection_),
            _router.getJotStakingAddress(collection_),
            _router.getCollectionManagerAddress(collection_),
            _openingBid,
            msg.sender
        );

        emit AuctionStarted(msg.sender, _openingBid);
    }
}
