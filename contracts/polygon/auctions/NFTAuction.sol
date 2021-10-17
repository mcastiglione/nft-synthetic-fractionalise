// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/ProtocolConstants.sol";
import "./AuctionsManager.sol";

/**
 * @title upgradeable auction contract
 * @author priviprotocol
 */
contract NFTAuction is Initializable, UUPSUpgradeable {
    /// @notice the date when the auction will finish
    uint256 public auctionEndTime;

    /// @notice the current highest bidder of the auction
    address public highestBidder;

    /// @notice the current highest bid of the auction
    uint256 public highestBid;

    /// @notice the id of the synthetic nft token being auctioned
    uint256 public nftId;

    /// @notice the address of the synthetic collection contract for this token
    address public syntheticCollection;

    /// @notice the address of the jot contract for the synthetic collection
    address public jot;

    /// @notice the address of the jot pool contract for the synthetic collection
    address public jotPool;

    /// @notice the address of auctions manager (auctions fabric)
    address public auctionsManager;

    /// @dev allowed withdrawals of previous bids
    mapping(address => uint256) private _pendingReturns;

    /// @dev set to true at the end, disallows any change.
    bool private _claimed;

    /**
     * @dev emitted when the highest bid gets increased
     * @param bidder the new highest bidder
     * @param amount the new highest bid
     */
    event HighestBidIncreased(address bidder, uint256 amount);

    /**
     * @dev emitted when the auction ends and the auction ends method is called
     * @param winner the highest bidder at the end
     * @param amount the highest bid at the end
     */
    event AuctionEnded(address winner, uint256 amount);

    /**
     * @dev the initializer modifier is to avoid someone initializing
     *      the implementation contract after deployment
     */
    constructor() initializer {} // solhint-disable-line

    /**
     * @dev initializes the auction (called by auctions manager after deploy)
     *
     * @param nftId_ the id of the nft being auctioned
     * @param jot_ the address of the jot contract
     * @param jotPool_ the address of the jot contract
     * @param syntheticCollection_ the address of the synthetic collection contract
     * @param initialBid_ the opening bid
     * @param auctionDuration_ the duration of the auction (protocol parameter set by governance)
     * @param initialBidder_ the initial bidder
     */
    function initialize(
        uint256 nftId_,
        address jot_,
        address jotPool_,
        address syntheticCollection_,
        uint256 initialBid_,
        uint256 auctionDuration_,
        address initialBidder_
    ) external initializer {
        nftId = nftId_;
        auctionEndTime = block.timestamp + auctionDuration_; // solhint-disable-line
        highestBid = initialBid_;
        jot = jot_;
        jotPool = jotPool_;
        syntheticCollection = syntheticCollection_;
        highestBidder = initialBidder_;
        auctionsManager = msg.sender;
    }

    /**
     * @notice bid on the auction.
     *         the value will only be refunded if the
     *         auction is not won.
     *
     * @param amount_ the bid amount
     */
    function bid(uint256 amount_) public payable {
        // revert the call if the bidding period is over
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

    /**
     * @notice withdraw a bid that was overbid
     */
    function withdraw() public {
        uint256 amount = _pendingReturns[msg.sender];
        if (amount > 0) {
            // avoid reentrancy by using check-effects-interaction pattern
            _pendingReturns[msg.sender] = 0;

            require(IERC20(jot).transfer(msg.sender, amount), "Unable to transfer jots");
        }
    }

    /**
     * @notice winner can claim the token after auction end time
     */
    function endAuction() public {
        // solhint-disable-next-line
        require(block.timestamp >= auctionEndTime, "Auction not yet ended");
        require(!_claimed, "Token has already been claimed");

        _claimed = true;

        // transfer the jots
        require(
            IERC20(jot).transfer(syntheticCollection, ProtocolConstants.JOT_SUPPLY),
            "Unable to transfer jots"
        );

        if (highestBid - ProtocolConstants.JOT_SUPPLY > 0) {
            require(
                IERC20(jot).transfer(jotPool, highestBid - ProtocolConstants.JOT_SUPPLY),
                "Unable to transfer jots"
            );
        }

        // reassign the NFT in the synthetic collection
        AuctionsManager(auctionsManager).reassignNFT(syntheticCollection, nftId, highestBidder);

        emit AuctionEnded(highestBidder, highestBid);
    }

    // solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal override {}
}
