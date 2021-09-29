// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title parameters controlled by governance
 * @notice the owner of this contract is the timelock controller of the governance feature
 */
contract ProtocolParameters is Ownable {
    // interval in seconds between the one flip to another in one lock contract
    uint256 public flippingInterval;

    // amount of reward that the flipper gets if he is right on the outcome
    uint256 public flippingReward;

    // amount of jots into play in each flip
    uint256 public flippingAmount;

    // the duration of an NFT auction in seconds
    uint256 public auctionDuration;

    // the period of grace to recover the nft after reaching 0 owner supply
    uint256 public recoveryThreshold;

    event FlippingIntervalUpdated(uint256 from, uint256 to);
    event FlippingRewardUpdated(uint256 from, uint256 to);
    event FlippingAmountUpdated(uint256 from, uint256 to);
    event AuctionDurationUpdated(uint256 from, uint256 to);
    event RecoveryThresholdUpdated(uint256 from, uint256 to);

    /**
     * @dev sets the default (initial) values of the parameters
     *      also transfers the ownership to the governance
     */
    constructor(
        uint256 flippingInterval_,
        uint256 flippingReward_,
        uint256 flippingAmount_,
        uint256 auctionDuration_,
        address governanceContractAddress_
    ) {
        require(flippingReward_ > 0, "Invalid Reward");
        require(flippingAmount_ > 0, "Invalid Amount");
        require(flippingReward_ < flippingAmount_, "Reward should be lower than Amount");
        require(flippingInterval_ > 15 minutes, "Flipping Interval should be greater than 15 minutes");
        require(auctionDuration_ > 1 hours, "Auction duration should be greater than 1 hour");

        flippingInterval = flippingInterval_;
        flippingReward = flippingReward_;
        flippingAmount = flippingAmount_;
        auctionDuration = auctionDuration_;

        // transfer ownership
        transferOwnership(governanceContractAddress_);
    }

    function setFlippingInterval(uint256 flippingInterval_) external onlyOwner {
        require(flippingInterval_ > 15 minutes, "Flipping Interval should be greater than 15 minutes");
        emit FlippingIntervalUpdated(flippingInterval, flippingInterval_);
        flippingInterval = flippingInterval_;
    }

    function setFlippingReward(uint256 flippingReward_) external onlyOwner {
        require(flippingReward_ > 0, "Invalid Reward");
        require(flippingReward_ < flippingAmount, "Reward should be lower than Amount");
        emit FlippingRewardUpdated(flippingReward, flippingReward_);
        flippingReward = flippingReward_;
    }

    function setFlippingAmount(uint256 flippingAmount_) external onlyOwner {
        require(flippingAmount_ > 0, "Invalid Amount");
        require(flippingReward < flippingAmount_, "Reward should be lower than Amount");
        emit FlippingAmountUpdated(flippingAmount, flippingAmount_);
        flippingAmount = flippingAmount_;
    }

    function setAuctionDuration(uint256 auctionDuration_) external onlyOwner {
        require(auctionDuration_ > 1 hours, "Auction duration should be greater than 1 hour");
        emit AuctionDurationUpdated(auctionDuration, auctionDuration_);
        auctionDuration = auctionDuration_;
    }

    function setRecoveryThreshold(uint256 recoveryThreshold_) external onlyOwner {
        require(recoveryThreshold_ > 1 hours, "Recovery threshold should be greater than 1 hour");
        emit RecoveryThresholdUpdated(recoveryThreshold, recoveryThreshold_);
        recoveryThreshold = recoveryThreshold_;
    }
}
