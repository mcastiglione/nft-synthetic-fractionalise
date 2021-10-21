// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Structs.sol";

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

    event MinPoolMarginRatioUpdated(int256 from, int256 to);
    event MinInitialMarginRatioUpdated(int256 from, int256 to);
    event MinMaintenanceMarginRatioUpdated(int256 from, int256 to);
    event MinLiquidationRewardUpdated(int256 from, int256 to);
    event MaxLiquidationRewardUpdated(int256 from, int256 to);
    event LiquidationCutRatioUpdated(int256 from, int256 to);
    event ProtocolFeeCollectRatioUpdated(int256 from, int256 to);
    event FuturesOracleAddressUpdated(address from, address to);
    event FuturesMultiplierUpdated(int256 from, int256 to);
    event FuturesFeeRatioUpdated(int256 from, int256 to);
    event FuturesFundingRateCoefficientUpdated(int256 from, int256 to);
    event OracleDelayUpdated(uint256 from, uint256 to);

    /**
     * @dev sets the default (initial) values of the parameters
     *      also transfers the ownership to the governance
     */
    constructor(
        MainParams memory mainParams,
        address _futuresOracleAddress,
        int256 _futuresMultiplier,
        int256 _futuresFeeRatio,
        int256 _futuresFundingRateCoefficient,
        uint256 _oracleDelay,
        address _governanceContractAddress
    ) {
        require(_futuresOracleAddress != address(0), "Oracle address can't be zero");
        require(_futuresMultiplier > 0, "Invalid futures multiplier");
        require(_futuresFeeRatio > 0, "Invalid futures fee ratio");
        require(_futuresFundingRateCoefficient > 0, "Invalid futures funding rate coefficient");

        minPoolMarginRatio = mainParams.minPoolMarginRatio;
        minInitialMarginRatio = mainParams.minInitialMarginRatio;
        minMaintenanceMarginRatio = mainParams.minMaintenanceMarginRatio;
        minLiquidationReward = mainParams.minLiquidationReward;
        maxLiquidationReward = mainParams.maxLiquidationReward;
        liquidationCutRatio = mainParams.liquidationCutRatio;
        protocolFeeCollectRatio = mainParams.protocolFeeCollectRatio;
        futuresOracleAddress = _futuresOracleAddress;
        futuresMultiplier = _futuresMultiplier;
        futuresFeeRatio = _futuresFeeRatio;
        futuresFundingRateCoefficient = _futuresFundingRateCoefficient;
        oracleDelay = _oracleDelay;

        // transfer ownership
        transferOwnership(_governanceContractAddress);
    }

    function setMinPoolMarginRatio(int256 _minPoolMarginRatio) external onlyOwner {
        emit MinPoolMarginRatioUpdated(minPoolMarginRatio, _minPoolMarginRatio);
        minPoolMarginRatio = _minPoolMarginRatio;
    }

    function setMinInitialMarginRatio(int256 _minInitialMarginRatio) external onlyOwner {
        emit MinInitialMarginRatioUpdated(minInitialMarginRatio, _minInitialMarginRatio);

        minInitialMarginRatio = _minInitialMarginRatio;
    }

    function setMinMaintenanceMarginRatio(int256 _minMaintenanceMarginRatio) external onlyOwner {
        emit MinMaintenanceMarginRatioUpdated(minMaintenanceMarginRatio, _minMaintenanceMarginRatio);
        minMaintenanceMarginRatio = _minMaintenanceMarginRatio;
    }

    function setMinLiquidationReward(int256 _minLiquidationReward) external onlyOwner {
        emit MinLiquidationRewardUpdated(minLiquidationReward, _minLiquidationReward);
        minLiquidationReward = _minLiquidationReward;
    }

    function setMaxLiquidationReward(int256 _maxLiquidationReward) external onlyOwner {
        emit MaxLiquidationRewardUpdated(maxLiquidationReward, _maxLiquidationReward);
        maxLiquidationReward = _maxLiquidationReward;
    }

    function setLiquidationCutRatio(int256 _liquidationCutRatio) external onlyOwner {
        emit LiquidationCutRatioUpdated(liquidationCutRatio, _liquidationCutRatio);
        liquidationCutRatio = _liquidationCutRatio;
    }

    function setProtocolFeeCollectRatio(int256 _protocolFeeCollectRatio) external onlyOwner {
        emit ProtocolFeeCollectRatioUpdated(protocolFeeCollectRatio, _protocolFeeCollectRatio);
        protocolFeeCollectRatio = _protocolFeeCollectRatio;
    }

    function setFuturesOracleAddress(address futuresOracleAddress_) external onlyOwner {
        require(futuresOracleAddress_ != address(0), "Oracle address can't be zero");
        emit FuturesOracleAddressUpdated(futuresOracleAddress, futuresOracleAddress_);
        futuresOracleAddress = futuresOracleAddress_;
    }

    function setFuturesMultiplier(int256 futuresMultiplier_) external onlyOwner {
        require(futuresMultiplier_ > 1 hours, "Invalid futures multiplier");
        emit FuturesMultiplierUpdated(futuresMultiplier, futuresMultiplier_);
        futuresMultiplier = futuresMultiplier_;
    }

    function setFuturesFeeRatio(int256 futuresFeeRatio_) external onlyOwner {
        require(futuresFeeRatio_ > 1 hours, "Invalid futures fee ratio");
        emit FuturesFeeRatioUpdated(futuresFeeRatio_, futuresFeeRatio_);
        futuresFeeRatio = futuresFeeRatio_;
    }

    function setFuturesFundingRateCoefficient(int256 futuresFundingRateCoefficient_) external onlyOwner {
        require(futuresFundingRateCoefficient_ > 1 hours, "Invalid futures funding rate coefficient");
        emit FuturesFundingRateCoefficientUpdated(
            futuresFundingRateCoefficient,
            futuresFundingRateCoefficient_
        );
        futuresFundingRateCoefficient = futuresFundingRateCoefficient_;
    }

    function setOracleDelay(uint256 _oracleDelay) external onlyOwner {
        emit OracleDelayUpdated(oracleDelay, _oracleDelay);
        oracleDelay = _oracleDelay;
    }
}
