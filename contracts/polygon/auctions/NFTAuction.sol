// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTAuction is Initializable {
    uint256 private constant BIDING_TIME = 1 weeks;

    // parameters of the auction. Times are either
    // absolute unix timestamps (seconds since 1970-01-01)
    // or time periods in seconds.
    uint256 public auctionEndTime;

    // current state of the auction.
    address public highestBidder;
    uint256 public highestBid;

    // getters
    address public jot;
    address public jotPool;
    address public syntheticCollection;

    // allowed withdrawals of previous bids
    mapping(address => uint256) private _pendingReturns;

    // set to true at the end, disallows any change.
    // by default initialized to `false`.
    bool private _claimed;

    // events that will be emitted on changes.
    event HighestBidIncreased(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    /// create a simple auction with `BIDING_TIME`
    function initialize(
        address jot_,
        address jotPool_,
        address syntheticCollection_,
        uint256 initialBid_,
        address initialBidder_
    ) external initializer {
        auctionEndTime = block.timestamp + BIDING_TIME; // solhint-disable-line
        highestBid = initialBid_;
        jot = jot_;
        jotPool = jotPool_;
        syntheticCollection = syntheticCollection_;
        highestBidder = initialBidder_;
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
    function claim() public {
        // solhint-disable-next-line
        require(block.timestamp >= auctionEndTime, "Auction not yet ended");
        require(msg.sender == highestBidder, "Only the winner can claim");
        require(!_claimed, "Token has already been claimed");

        _claimed = true;
        emit AuctionEnded(highestBidder, highestBid);

        // TODO: transfer the synthetic token
    }
}
