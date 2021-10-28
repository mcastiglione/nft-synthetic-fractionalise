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

    // Address of the funding token for new manager
    address public fundingTokenAddress;

    uint256 public buybackPrice;

    uint256 public stakerShare;

    uint256 public liquidityPerpetualPercentage;

    uint256 public liquidityUniswapPercentage;

    event FlippingIntervalUpdated(uint256 from, uint256 to);
    event FlippingRewardUpdated(uint256 from, uint256 to);
    event FlippingAmountUpdated(uint256 from, uint256 to);
    event AuctionDurationUpdated(uint256 from, uint256 to);
    event RecoveryThresholdUpdated(uint256 from, uint256 to);
    event FundingTokenAddressUpdated(address from, address to);
    event BuybackPriceUpdated(uint256 from, uint256 to);
    event StakerShareUpdated(uint256 from, uint256 to);
    event LiquidityPercentagesUpdated(
        uint256 perpetualFrom,
        uint256 uniswapFrom,
        uint256 perpetualTo,
        uint256 uniswapTo
    );

    /**
     * @dev sets the default (initial) values of the parameters
     *      also transfers the ownership to the governance
     */
    constructor(
        uint256 flippingInterval_,
        uint256 flippingReward_,
        uint256 flippingAmount_,
        uint256 auctionDuration_,
        address governanceContractAddress_,
        address fundingTokenAddress_,
        uint256 liquidityPerpetualPercentage_,
        uint256 liquidityUniswapPercentage_,
        uint256 buybackPrice_
    ) {
        require(flippingReward_ > 0, "Invalid Reward");
        require(flippingAmount_ > 0, "Invalid Amount");
        require(flippingReward_ < flippingAmount_, "Reward should be lower than Amount");
        require(flippingInterval_ > 15 minutes, "Flipping Interval should be greater than 15 minutes");
        require(auctionDuration_ > 1 hours, "Auction duration should be greater than 1 hour");
        require(fundingTokenAddress_ != address(0), "Funding token address can't be zero");
        require(buybackPrice_ > 0, "Buyback price can't be zero");
        require(
            (liquidityPerpetualPercentage_ + liquidityUniswapPercentage_ == 100),
            "uniswap and perpetual percentages must sum 100"
        );

        flippingInterval = flippingInterval_;
        flippingReward = flippingReward_;
        flippingAmount = flippingAmount_;
        auctionDuration = auctionDuration_;
        fundingTokenAddress = fundingTokenAddress_;
        liquidityPerpetualPercentage = liquidityPerpetualPercentage_;
        liquidityUniswapPercentage = liquidityUniswapPercentage_;
        buybackPrice = buybackPrice_;
        stakerShare = 10;

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

    function setFundingTokenAddress(address fundingTokenAddress_) external onlyOwner {
        require(fundingTokenAddress_ != address(0), "Funding token address can't be zero");
        emit FundingTokenAddressUpdated(fundingTokenAddress, fundingTokenAddress_);
        fundingTokenAddress = fundingTokenAddress_;
    }

    function setBuybackPrice(uint256 buybackPrice_) external onlyOwner {
        require(buybackPrice > 0, "Buyback price can't be zero");
        emit BuybackPriceUpdated(buybackPrice, buybackPrice_);
        buybackPrice = buybackPrice_;
    }

    function setStakerShare(uint256 stakerShare_) external onlyOwner {
        require(stakerShare > 0, "Staker share can't be 0");
        emit StakerShareUpdated(stakerShare, stakerShare_);
        stakerShare = stakerShare_;
    }

    function setLiquidityPercentages(
        uint256 liquidityUniswapPercentage_,
        uint256 liquidityPerpetualPercentage_
    ) external onlyOwner {
        require((liquidityUniswapPercentage_ + liquidityPerpetualPercentage_) == 100, "Values must sum 100");

        emit LiquidityPercentagesUpdated(
            liquidityPerpetualPercentage,
            liquidityUniswapPercentage,
            liquidityPerpetualPercentage_,
            liquidityUniswapPercentage_
        );

        liquidityPerpetualPercentage = liquidityPerpetualPercentage_;
        liquidityUniswapPercentage = liquidityUniswapPercentage_;
    }
}
