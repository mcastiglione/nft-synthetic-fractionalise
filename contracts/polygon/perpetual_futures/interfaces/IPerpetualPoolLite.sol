// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IPerpetualPoolLite {
    struct SymbolInfo {
        string symbol;
        int256 price;
        int256 cumulativeFundingRate;
        int256 tradersNetVolume;
        int256 tradersNetCost;
    }

    struct SignedPrice {
        uint256 timestamp;
        uint256 price;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    event AddLiquidity(address indexed account, uint256 lShares, uint256 bAmount);

    event RemoveLiquidity(address indexed account, uint256 lShares, uint256 bAmount);

    event AddMargin(address indexed account, uint256 bAmount);

    event RemoveMargin(address indexed account, uint256 bAmount);

    event Trade(address indexed account, int256 tradeVolume, uint256 price);

    event Liquidate(address indexed account, address indexed liquidator, uint256 reward);

    event ProtocolFeeCollection(address indexed collector, uint256 amount);

    function getParameters()
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
        );

    function getAddresses()
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
        );

    function getSymbol() external view returns (SymbolInfo memory);

    function getLiquidity() external view returns (int256);

    function getLastUpdateBlock() external view returns (uint256);

    function getProtocolFeeAccrued() external view returns (int256);

    function collectProtocolFee() external;

    function addLiquidity(uint256 bAmount) external;

    function removeLiquidity(uint256 lShares) external;

    function addMargin(uint256 bAmount) external;

    function removeMargin(uint256 bAmount) external;

    function trade(int256 tradeVolume) external;

    function liquidate(address account) external;

    function addLiquidity(uint256 bAmount, SignedPrice memory price) external;

    function removeLiquidity(uint256 lShares, SignedPrice memory price) external;

    function addMargin(uint256 bAmount, SignedPrice memory price) external;

    function removeMargin(uint256 bAmount, SignedPrice memory price) external;

    function trade(int256 tradeVolume, SignedPrice memory price) external;

    function liquidate(address account, SignedPrice memory price) external;
}
