// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./PerpetualPoolLite.sol";
import "./library/SafeMath.sol";
import "../polygon/Interfaces.sol";

contract PoolInfo is Initializable {
    using SafeMath for int256;

    int256 private constant ONE = 10**18;
    address public poolAddress;

    function initialize(address _poolAddress) external initializer {
        poolAddress = _poolAddress;
    }

    function getProtocolParameters()
        external
        view
        returns (
            int256 minPoolMarginRatio,
            int256 minInitialMarginRatio,
            int256 minMaintenanceMarginRatio,
            int256 minLiquidationReward,
            int256 maxLiquidationReward,
            int256 liquidationCutRatio,
            int256 protocolFeeCollectRatio
        )
    {
        return PerpetualPoolLite(poolAddress).getParameters();
    }

    function getProtocolAddresses()
        external
        view
        returns (
            address bTokenAddress,
            address lTokenAddress,
            address pTokenAddress,
            address liquidatorQualifierAddress,
            address protocolFeeCollector,
            address underlyingAddress,
            address protocolAddress
        )
    {
        return PerpetualPoolLite(poolAddress).getAddresses();
    }

    function getLiquidity() external view returns (int256) {
        return PerpetualPoolLite(poolAddress).getLiquidity();
    }

    function getLastUpdateBlock() external view returns (uint256) {
        return PerpetualPoolLite(poolAddress).getLastUpdateBlock();
    }

    function getFeeAccrued() external view returns (int256) {
        return PerpetualPoolLite(poolAddress).getProtocolFeeAccrued();
    }

    function getTraderPortfolio(address account)
        public
        view
        returns (IPTokenLite.Position memory position, int256 margin)
    {
        return PerpetualPoolLite(poolAddress).getTraderPortfolio(account);
    }

    function getTraderMarginRatio(address account) external view returns (int256) {
        (IPTokenLite.Position memory position, int256 margin) = getTraderPortfolio(account);

        (int256 price, int256 multiplier) = PerpetualPoolLite(poolAddress).getSymbolPriceAndMultiplier();

        int256 totalDynamicEquity = margin;
        int256 totalAbsCost;
        if (position.volume != 0) {
            int256 cost = (((position.volume * price) / ONE) * multiplier) / ONE;
            totalDynamicEquity += cost - position.cost;
            totalAbsCost += cost.abs();
        }
        return totalAbsCost == 0 ? type(int256).max : (totalDynamicEquity * ONE) / totalAbsCost;
    }
}
