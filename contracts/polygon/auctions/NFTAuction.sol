// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AuctionsManager.sol";

contract NFTAuction is Initializable {
    // parameters of the auction. Times are either
    // absolute unix timestamps (seconds since 1970-01-01)
    // or time periods in seconds.
    uint256 public auctionEndTime;

    // current state of the auction.
    address public highestBidder;
    uint256 public highestBid;

    // getters
    uint256 public nftId;
    address public jot;
    address public jotPool;
    address public syntheticCollection;
    address public auctionsManager;

    // allowed withdrawals of previous bids
    mapping(address => uint256) private _pendingReturns;

    // set to true at the end, disallows any change.
    // by default initialized to `false`.
    bool private _claimed;

    uint256 private _jotSupply;

    // events that will be emitted on changes.
    event HighestBidIncreased(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    /// create a simple auction
    function initialize(
        uint256 nftId_,
        address jot_,
        address jotPool_,
        address syntheticCollection_,
        uint256 jotSupply_,
        uint256 initialBid_,
        uint256 auctionDuration_,
        address initialBidder_
    ) external initializer {
        nftId = nftId_;
        auctionEndTime = block.timestamp + auctionDuration_; // solhint-disable-line
        highestBid = initialBid_;
        _jotSupply = jotSupply_;
        jot = jot_;
        jotPool = jotPool_;
        syntheticCollection = syntheticCollection_;
        highestBidder = initialBidder_;
        auctionsManager = msg.sender;
    }

    /// bid on the auction.
    /// the value will only be refunded if the
    /// auction is not won.
    function bid(uint256 amount_) public payable {
        // revert the call if the bidding
        // period is over.
        // solhint-disable-next-line
        require(block.timestamp <= auctionEndTime, "Auction already ended");

        // if the bid is not higher revert
        require(amount_ > highestBid, "There already is a higher bid");

        // if the allowance is not enough or transfer fails revert
        require(IERC20(jot).transferFrom(msg.sender, address(this), amount_), "Unable to transfer jots");

        if (highestBid != 0) {
            // sending back the money by simply using
            // highestBidder.send(highestBid) is a security risk
            // because it could execute an untrusted contract.
            // it is always safer to let the recipients
            // withdraw their money themselves.
            _pendingReturns[highestBidder] += highestBid;
        }
        highestBidder = msg.sender;
        highestBid = amount_;

        emit HighestBidIncreased(msg.sender, amount_);
    }

    /// withdraw a bid that was overbid.
    function withdraw() public {
        uint256 amount = _pendingReturns[msg.sender];
        if (amount > 0) {
            // avoid reentrancy
            _pendingReturns[msg.sender] = 0;

            require(IERC20(jot).transfer(msg.sender, amount), "Unable to transfer jots");
        }
    }

    /// winner can claim the token after auction end time
    function endAuction() public {
        // solhint-disable-next-line
        require(block.timestamp >= auctionEndTime, "Auction not yet ended");
        require(!_claimed, "Token has already been claimed");

        _claimed = true;

        // transfer the jots
        require(IERC20(jot).transfer(jot, _jotSupply), "Unable to transfer jots");

        if (highestBid - _jotSupply > 0) {
            require(IERC20(jot).transfer(jotPool, highestBid - _jotSupply), "Unable to transfer jots");
        }

        // reassign the NFT in the synthetic collection
        AuctionsManager(auctionsManager).reassignNFT(syntheticCollection, nftId, highestBidder, _jotSupply);

        emit AuctionEnded(highestBidder, highestBid);
    }
}
