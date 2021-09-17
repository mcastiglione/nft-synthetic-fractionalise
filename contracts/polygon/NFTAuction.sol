// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTAuction is Ownable {
    // Parameters of the auction. Times are either
    // absolute unix timestamps (seconds since 1970-01-01)
    // or time periods in seconds.
    address payable public beneficiary; // delete
    uint256 public auctionEndTime;

    // Current state of the auction.
    address public highestBidder;
    uint256 public highestBid;
    uint256 private minimumBid;

    // Allowed withdrawals of previous bids
    mapping(address => uint256) private _pendingReturns;

    // Set to true at the end, disallows any change.
    // By default initialized to `false`.
    bool private _ended;

    // Events that will be emitted on changes.
    event HighestBidIncreased(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    /// Create a simple auction with `_biddingTime`
    /// seconds bidding time on behalf of the
    /// beneficiary address `_beneficiary`.
    constructor(
        uint256 _biddingTime,
        address payable _beneficiary,
        uint256 minimumBid_
    ) {
        beneficiary = _beneficiary;
        auctionEndTime = block.timestamp + _biddingTime; // solhint-disable-line
        highestBid = minimumBid_;
        minimumBid = minimumBid_;
        highestBidder = address(0);
    }

    /// Bid on the auction with the value sent
    /// together with this transaction.
    /// The value will only be refunded if the
    /// auction is not won.
    function bid() public payable {
        // Revert the call if the bidding
        // period is over.
        // solhint-disable-next-line
        require(block.timestamp <= auctionEndTime, "Auction already ended.");

        // If the bid is not higher, send the
        // money back (the failing require
        // will revert all changes in this
        // function execution including
        // it having received the money).
        require(msg.value > highestBid, "There already is a higher bid.");

        if (highestBid != 0) {
            // Sending back the money by simply using
            // highestBidder.send(highestBid) is a security risk
            // because it could execute an untrusted contract.
            // It is always safer to let the recipients
            // withdraw their money themselves.
            _pendingReturns[highestBidder] += highestBid;
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    /// Withdraw a bid that was overbid.
    function withdraw() public returns (bool) {
        uint256 amount = _pendingReturns[msg.sender];
        if (amount > 0) {
            // It is important to set this to zero because the recipient
            // can call this function again as part of the receiving call
            // before `send` returns.
            _pendingReturns[msg.sender] = 0;

            if (!payable(msg.sender).send(amount)) {
                // No need to call throw here, just reset the amount owing
                _pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    /// End the auction and send the highest bid
    /// to the beneficiary.
    function auctionEnd() public {
        // 1. Conditions
        require(highestBid > minimumBid);
        require(msg.sender == address(owner()));
        require(block.timestamp >= auctionEndTime, "Auction not yet ended.");
        require(!_ended, "auctionEnd has already been called.");

        // 2. Change state and record event
        _ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        // 3. Send highest bid
        beneficiary.transfer(highestBid);
    }

    /**
     * @dev returns address of contract
     */

    function getAddress() public view returns (address) {
        return address(this);
    }
}
