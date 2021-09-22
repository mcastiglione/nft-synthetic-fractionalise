// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title parameters controlled by governance
 * @notice the owner of this contract is the timelock controller of the governance feature
 */
contract ProtocolParameters is Ownable {
    // this is the number of Jots minted when a new single NFT is synthetic fractionalised
    uint256 public jotsSupply;

    // interval in seconds between the one flip to another in one lock contract
    uint256 public flippingInterval;

    // amount of reward that the flipper gets if he is right on the outcome
    uint256 public flippingReward;

    // amount of jots into play in each flip
    uint256 public flippingAmount;

    // the duration of an NFT auction in seconds
    uint256 public auctionDuration;


    // the implementation of FlipCoinGenerator
    address public flipCoinGenerator;

    // futures variables 
    address public futuresOracleAddress;
    uint256 public futuresMultiplier;
    uint256 public futuresFeeRatio;
    uint256 public futuresFundingRateCoefficient;

    event JotsSupplyUpdated(uint256 value);
    event FlippingIntervalUpdated(uint256 value);
    event FlippingRewardUpdated(uint256 value);
    event FlippingAmountUpdated(uint256 value);
    event AuctionDurationUpdated(uint256 value);
    event FlipCoinGeneratorUpdated(address value);
    event FuturesOracleAddressUpdated(address value);
    event FuturesMultiplierUpdated(uint256 value);
    event FuturesFeeRatioUpdated(uint256 value);
    event FuturesFundingRateCoefficientUpdated(uint256 value);

    /**
     * @dev sets the default (initial) values of the parameters
     *      also transfers the ownership to the governance
     */
    constructor(
        uint256 jotsSupply_,
        uint256 flippingInterval_,
        uint256 flippingReward_,
        uint256 flippingAmount_,
        uint256 auctionDuration_,
        address governanceContractAddress_,
        address futuresOracleAddress_,
        uint256 futuresMultiplier_,
        uint256 futuresFeeRatio_,
        uint256 futuresFundingRateCoefficient_
    ) {
        require(flippingReward_ > 0, "Invalid Reward");
        require(flippingAmount_ > 0, "Invalid Amount");
        require(flippingReward_ < flippingAmount_, "Reward should be lower than Amount");
        require(jotsSupply_ > 0, "Invalid Jots Supply");
        require(flippingInterval_ > 15 minutes, "Flipping Interval should be greater than 15 minutes");
        require(auctionDuration_ > 1 hours, "Auction duration should be greater than 1 hour");
        require(futuresOracleAddress_ != address(0), "Oracle address can't be zero");
        require(futuresMultiplier_ > 0, "Invalid futures multiplier");
        require(futuresFeeRatio_> 0, "Invalid futures fee ratio");
        require(futuresFundingRateCoefficient_ > 0, "Invalid futures funding rate coefficient");

        jotsSupply = jotsSupply_;
        flippingInterval = flippingInterval_;
        flippingReward = flippingReward_;
        flippingAmount = flippingAmount_;
        auctionDuration = auctionDuration_;

        futuresOracleAddress = futuresOracleAddress_;
        futuresMultiplier = futuresMultiplier_;
        futuresFeeRatio = futuresFeeRatio_;
        futuresFundingRateCoefficient = futuresFundingRateCoefficient_;

        // transfer ownership
        transferOwnership(governanceContractAddress_);
    }

    function setJotsSupply(uint256 jotsSupply_) external onlyOwner {
        require(jotsSupply_ > 0, "Invalid Jots Supply");
        jotsSupply = jotsSupply_;
        emit JotsSupplyUpdated(jotsSupply_);
    }

    function setFlippingInterval(uint256 flippingInterval_) external onlyOwner {
        require(flippingInterval_ > 15 minutes, "Flipping Interval should be greater than 15 minutes");
        flippingInterval = flippingInterval_;
        emit FlippingIntervalUpdated(flippingInterval_);
    }

    function setFlippingReward(uint256 flippingReward_) external onlyOwner {
        require(flippingReward_ > 0, "Invalid Reward");
        require(flippingReward_ < flippingAmount, "Reward should be lower than Amount");
        flippingReward = flippingReward_;
        emit FlippingRewardUpdated(flippingReward_);
    }

    function setFlippingAmount(uint256 flippingAmount_) external onlyOwner {
        require(flippingAmount_ > 0, "Invalid Amount");
        require(flippingReward < flippingAmount_, "Reward should be lower than Amount");
        flippingAmount = flippingAmount_;
        emit FlippingAmountUpdated(flippingAmount_);
    }

    function setAuctionDuration(uint256 auctionDuration_) external onlyOwner {
        require(auctionDuration_ > 1 hours, "Auction duration should be greater than 1 hour");
        auctionDuration = auctionDuration_;
        emit AuctionDurationUpdated(auctionDuration_);
    }

    function setFuturesOracleAddress(address futuresOracleAddress_) external onlyOwner {
        require(futuresOracleAddress_ != address(0), "Oracle address can't be zero");
        futuresOracleAddress = futuresOracleAddress_;
        emit FuturesOracleAddressUpdated(futuresOracleAddress_);
    }

    function setFuturesMultiplier(uint256 futuresMultiplier_) external onlyOwner {
        require(futuresMultiplier_ > 1 hours, "Invalid futures multiplier");
        futuresMultiplier = futuresMultiplier_;
        emit FuturesMultiplierUpdated(futuresMultiplier_);
    }

    function setFuturesFeeRatio(uint256 futuresFeeRatio_) external onlyOwner {
        require(futuresFeeRatio_ > 1 hours, "Invalid futures fee ratio");
        futuresFeeRatio = futuresFeeRatio_;
        emit FuturesFeeRatioUpdated(futuresFeeRatio_);
    }

    function setFuturesFundingRateCoefficient(uint256 futuresFundingRateCoefficient_) external onlyOwner {
        require(futuresFundingRateCoefficient_ > 1 hours, "Invalid futures funding rate coefficient");
        futuresFundingRateCoefficient = futuresFundingRateCoefficient_;
        emit FuturesFundingRateCoefficientUpdated(futuresFundingRateCoefficient_);
    }

}
