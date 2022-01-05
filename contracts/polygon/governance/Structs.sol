// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

struct MainParams {
    int256 minPoolMarginRatio;
    int256 minInitialMarginRatio;
    int256 minMaintenanceMarginRatio;
    int256 minLiquidationReward;
    int256 maxLiquidationReward;
    int256 liquidationCutRatio;
    int256 protocolFeeCollectRatio;
}
