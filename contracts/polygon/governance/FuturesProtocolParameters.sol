// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

// ! TODO: EMIT THE EVENTS AND ADD VALIDATIONS

/**
 * @title future parameters controlled by governance
 * @notice the owner of this contract is the timelock controller of the governance feature
 */
contract FuturesProtocolParameters is Ownable {
    int256 public minPoolMarginRatio;
    int256 public minInitialMarginRatio;
    int256 public minMaintenanceMarginRatio;
    int256 public minLiquidationReward;
    int256 public maxLiquidationReward;
    int256 public liquidationCutRatio;
    int256 public protocolFeeCollectRatio;
    address public futuresOracleAddress;
    int256 public futuresMultiplier;
    int256 public futuresFeeRatio;
    int256 public futuresFundingRateCoefficient;
    uint256 public oracleDelay;

    event MinPoolMarginRatioUpdated(address value);
    event MinInitialMarginRatioUpdated(address value);
    event MinMaintenanceMarginRatioUpdated(address value);
    event MinLiquidationRewardUpdated(address value);
    event MaxLiquidationRewardUpdated(address value);
    event LiquidationCutRatioUpdated(address value);
    event ProtocolFeeCollectRatioUpdated(address value);
    event OracleDelayUpdated(address value);
    event FuturesOracleAddressUpdated(address value);
    event FuturesMultiplierUpdated(int256 value);
    event FuturesFeeRatioUpdated(int256 value);
    event FuturesFundingRateCoefficientUpdated(int256 value);

    /**
     * @dev set initial state of the data
     */
    constructor(
        int256 _minPoolMarginRatio,
        int256 _minInitialMarginRatio,
        int256 _minMaintenanceMarginRatio,
        int256 _minLiquidationReward,
        int256 _maxLiquidationReward,
        int256 _liquidationCutRatio,
        int256 _protocolFeeCollectRatio,
        address _futuresOracleAddress,
        int256 _futuresMultiplier,
        int256 _futuresFeeRatio,
        int256 _futuresFundingRateCoefficient,
        uint256 _oracleDelay
    ) {
        require(_futuresOracleAddress != address(0), "Oracle address can't be zero");
        require(_futuresMultiplier > 0, "Invalid futures multiplier");
        require(_futuresFeeRatio > 0, "Invalid futures fee ratio");
        require(_futuresFundingRateCoefficient > 0, "Invalid futures funding rate coefficient");

        minPoolMarginRatio = _minPoolMarginRatio;
        minInitialMarginRatio = _minInitialMarginRatio;
        minMaintenanceMarginRatio = _minMaintenanceMarginRatio;
        minLiquidationReward = _minLiquidationReward;
        maxLiquidationReward = _maxLiquidationReward;
        liquidationCutRatio = _liquidationCutRatio;
        protocolFeeCollectRatio = _protocolFeeCollectRatio;
        futuresOracleAddress = _futuresOracleAddress;
        futuresMultiplier = _futuresMultiplier;
        futuresFeeRatio = _futuresFeeRatio;
        futuresFundingRateCoefficient = _futuresFundingRateCoefficient;
        oracleDelay = _oracleDelay;
    }

    function setMinPoolMarginRatio(int256 _minPoolMarginRatio) external onlyOwner {
        minPoolMarginRatio = _minPoolMarginRatio;
    }

    function setMinInitialMarginRatio(int256 _minInitialMarginRatio) external onlyOwner {
        minInitialMarginRatio = _minInitialMarginRatio;
    }

    function setMinMaintenanceMarginRatio(int256 _minMaintenanceMarginRatio) external onlyOwner {
        minMaintenanceMarginRatio = _minMaintenanceMarginRatio;
    }

    function setMinLiquidationReward(int256 _minLiquidationReward) external onlyOwner {
        minLiquidationReward = _minLiquidationReward;
    }

    function setMaxLiquidationReward(int256 _maxLiquidationReward) external onlyOwner {
        maxLiquidationReward = _maxLiquidationReward;
    }

    function setLiquidationCutRatio(int256 _liquidationCutRatio) external onlyOwner {
        liquidationCutRatio = _liquidationCutRatio;
    }

    function setProtocolFeeCollectRatio(int256 _protocolFeeCollectRatio) external onlyOwner {
        protocolFeeCollectRatio = _protocolFeeCollectRatio;
    }

    function setFuturesOracleAddress(address futuresOracleAddress_) external onlyOwner {
        require(futuresOracleAddress_ != address(0), "Oracle address can't be zero");
        futuresOracleAddress = futuresOracleAddress_;
        emit FuturesOracleAddressUpdated(futuresOracleAddress_);
    }

    function setFuturesMultiplier(int256 futuresMultiplier_) external onlyOwner {
        require(futuresMultiplier_ > 1 hours, "Invalid futures multiplier");
        futuresMultiplier = futuresMultiplier_;
        emit FuturesMultiplierUpdated(futuresMultiplier_);
    }

    function setFuturesFeeRatio(int256 futuresFeeRatio_) external onlyOwner {
        require(futuresFeeRatio_ > 1 hours, "Invalid futures fee ratio");
        futuresFeeRatio = futuresFeeRatio_;
        emit FuturesFeeRatioUpdated(futuresFeeRatio_);
    }

    function setFuturesFundingRateCoefficient(int256 futuresFundingRateCoefficient_) external onlyOwner {
        require(futuresFundingRateCoefficient_ > 1 hours, "Invalid futures funding rate coefficient");
        futuresFundingRateCoefficient = futuresFundingRateCoefficient_;
        emit FuturesFundingRateCoefficientUpdated(futuresFundingRateCoefficient_);
    }

    function setOracleDelay(uint256 _oracleDelay) external onlyOwner {
        oracleDelay = _oracleDelay;
    }
}
