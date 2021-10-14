// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../polygon/Interfaces.sol";
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./library/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../polygon/governance/FuturesProtocolParameters.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

contract PerpetualPoolLite is IPerpetualPoolLite, Initializable {
    using SafeMath for uint256;
    using SafeMath for int256;
    using SafeERC20 for IERC20;

    int256 private constant ONE = 10**18;

    uint256 private _decimals;

    address private _bTokenAddress;
    address private _lTokenAddress;
    address private _pTokenAddress;
    address private _liquidatorQualifierAddress;
    address private _protocolFeeCollector;
    address private _underlyingAddress;
    address private immutable _protocolAddress;
    FuturesProtocolParameters private immutable _protocolParameters;

    int256 private _liquidity;

    uint256 private _lastUpdateBlock;
    int256 private _protocolFeeAccrued;

    // symbolId => SymbolInfo
    SymbolInfo private _symbol;

    bool private _mutex;
    modifier _lock_() {
        require(!_mutex, "reentry");
        _mutex = true;
        _;
        _mutex = false;
    }

    constructor(address[2] memory addresses) {
        _protocolAddress = addresses[0];
        _protocolParameters = FuturesProtocolParameters(addresses[0]);
    }

    function initialize(address[6] memory addresses) external initializer {
        _bTokenAddress = addresses[0];
        _lTokenAddress = addresses[1];
        _pTokenAddress = addresses[2];
        _liquidatorQualifierAddress = addresses[3];
        _protocolFeeCollector = addresses[4];
        _underlyingAddress = addresses[5];

        _decimals = 6;
    }

    function getSymbolPriceAndMultiplier() external view returns (int256 price, int256 multiplier) {
        return (_symbol.price, _protocolParameters.futuresMultiplier());
    }

    function getParameters()
        external
        view
        override
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
        return (
            _protocolParameters.minPoolMarginRatio(),
            _protocolParameters.minInitialMarginRatio(),
            _protocolParameters.minMaintenanceMarginRatio(),
            _protocolParameters.minLiquidationReward(),
            _protocolParameters.maxLiquidationReward(),
            _protocolParameters.liquidationCutRatio(),
            _protocolParameters.protocolFeeCollectRatio()
        );
    }

    function getAddresses()
        external
        view
        override
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
        return (
            _bTokenAddress,
            _lTokenAddress,
            _pTokenAddress,
            _liquidatorQualifierAddress,
            _protocolFeeCollector,
            _underlyingAddress,
            _protocolAddress
        );
    }

    function getSymbol() external view override returns (SymbolInfo memory) {
        return _symbol;
    }

    function getLiquidity() external view override returns (int256) {
        return _liquidity;
    }

    function getLastUpdateBlock() external view override returns (uint256) {
        return _lastUpdateBlock;
    }

    function getProtocolFeeAccrued() external view override returns (int256) {
        return _protocolFeeAccrued;
    }

    function collectProtocolFee() external override {
        uint256 balance = IERC20(_bTokenAddress).balanceOf(address(this)).rescale(_decimals, 18);
        uint256 amount = _protocolFeeAccrued.itou();
        if (amount > balance) amount = balance;
        _protocolFeeAccrued -= amount.utoi();
        _transferOut(_protocolFeeCollector, amount);
        emit ProtocolFeeCollection(_protocolFeeCollector, amount);
    }

    //================================================================================
    // Interactions with onchain oracles
    //================================================================================

    function addLiquidity(uint256 bAmount) external override {
        require(bAmount > 0, "PerpetualPool: 0 bAmount");
        _addLiquidity(msg.sender, bAmount);
    }

    function removeLiquidity(uint256 lShares) external override {
        require(lShares > 0, "PerpetualPool: 0 lShares");
        _removeLiquidity(msg.sender, lShares);
    }

    function addMargin(uint256 bAmount) external override {
        require(bAmount > 0, "PerpetualPool: 0 bAmount");
        _addMargin(msg.sender, bAmount);
    }

    function removeMargin(uint256 bAmount) external override {
        require(bAmount > 0, "PerpetualPool: 0 bAmount");
        _removeMargin(msg.sender, bAmount);
    }

    function trade(int256 tradeVolume) external override {
        require(
            tradeVolume != 0 && (tradeVolume / ONE) * ONE == tradeVolume,
            "PerpetualPool: invalid tradeVolume"
        );
        _trade(msg.sender, tradeVolume);
    }

    function liquidate(address account) external override {
        address liquidator = msg.sender;
        require(
            _liquidatorQualifierAddress == address(0) ||
                ILiquidatorQualifier(_liquidatorQualifierAddress).isQualifiedLiquidator(liquidator),
            "PerpetualPool: not qualified liquidator"
        );
        _liquidate(liquidator, account);
    }

    //================================================================================
    // Interactions with offchain oracles
    //================================================================================

    function addLiquidity(uint256 bAmount, SignedPrice memory price) external override {
        require(bAmount > 0, "PerpetualPool: 0 bAmount");
        _updateSymbolOracles(price);
        _addLiquidity(msg.sender, bAmount);
    }

    function removeLiquidity(uint256 lShares, SignedPrice memory price) external override {
        require(lShares > 0, "PerpetualPool: 0 lShares");
        _updateSymbolOracles(price);
        _removeLiquidity(msg.sender, lShares);
    }

    function addMargin(uint256 bAmount, SignedPrice memory price) external override {
        require(bAmount > 0, "PerpetualPool: 0 bAmount");
        _updateSymbolOracles(price);
        _addMargin(msg.sender, bAmount);
    }

    function removeMargin(uint256 bAmount, SignedPrice memory price) external override {
        require(bAmount > 0, "PerpetualPool: 0 bAmount");
        _updateSymbolOracles(price);
        _removeMargin(msg.sender, bAmount);
    }

    function trade(int256 tradeVolume, SignedPrice memory price) external override {
        require(
            tradeVolume != 0 && (tradeVolume / ONE) * ONE == tradeVolume,
            "PerpetualPool: invalid tradeVolume"
        );
        _updateSymbolOracles(price);
        _trade(msg.sender, tradeVolume);
    }

    function liquidate(address account, SignedPrice memory price) external override {
        address liquidator = msg.sender;
        require(
            _liquidatorQualifierAddress == address(0) ||
                ILiquidatorQualifier(_liquidatorQualifierAddress).isQualifiedLiquidator(liquidator),
            "PerpetualPool: not qualified liquidator"
        );
        _updateSymbolOracles(price);
        _liquidate(liquidator, account);
    }

    //================================================================================
    // Core logics
    //================================================================================

    function _addLiquidity(address account, uint256 bAmount) internal _lock_ {
        (int256 totalDynamicEquity, ) = _updateSymbolPricesAndFundingRates();
        bAmount = _transferIn(account, bAmount);
        ILTokenLite lToken = ILTokenLite(_lTokenAddress);

        uint256 totalSupply = lToken.totalSupply();

        uint256 lShares;
        if (totalSupply == 0) {
            lShares = bAmount;
        } else {
            lShares = (bAmount * totalSupply) / totalDynamicEquity.itou();
        }

        lToken.mint(account, lShares);
        _liquidity += bAmount.utoi();

        emit AddLiquidity(account, lShares, bAmount);
    }

    function _removeLiquidity(address account, uint256 lShares) internal _lock_ {
        (int256 totalDynamicEquity, int256 totalAbsCost) = _updateSymbolPricesAndFundingRates();
        ILTokenLite lToken = ILTokenLite(_lTokenAddress);

        uint256 totalSupply = lToken.totalSupply();
        require(totalSupply > 0, "There's no LToken supply");
        uint256 bAmount = (lShares * totalDynamicEquity.itou()) / totalSupply;
        

        _liquidity -= bAmount.utoi();

        require(
            totalAbsCost == 0 ||
                ((totalDynamicEquity - bAmount.utoi()) * ONE) / totalAbsCost >=
                _protocolParameters.minPoolMarginRatio(),
            "PerpetualPool: pool insufficient margin"
        );

        lToken.burn(account, lShares);
        _transferOut(account, bAmount);

        emit RemoveLiquidity(account, lShares, bAmount);
    }

    function _addMargin(address account, uint256 bAmount) internal _lock_ {
        IPTokenLite pToken = IPTokenLite(_pTokenAddress);
        require(!pToken.exists(account), "Ptoken doesn't exist for this address");
        bAmount = _transferIn(account, bAmount);
        pToken.mint(account);
        pToken.addMargin(account, bAmount.utoi());
        emit AddMargin(account, bAmount);
    }

    function _removeMargin(address account, uint256 bAmount) internal _lock_ {
        _updateSymbolPricesAndFundingRates();
        (IPTokenLite.Position memory position, int256 margin) = _settleTraderFundingFee(account);

        int256 amount = bAmount.utoi();
        if (amount >= margin) {
            amount = margin;
            bAmount = amount.itou();
            margin = 0;
        } else {
            margin -= amount;
        }

        require(
            _getTraderMarginRatio(position, margin) >= _protocolParameters.minInitialMarginRatio(),
            "PerpetualPool: insufficient margin"
        );

        _updateTraderPortfolio(account, position, margin);
        _transferOut(account, bAmount);

        emit RemoveMargin(account, bAmount);
    }

    // struct for temp use in trade function, to prevent stack too deep error
    struct TradeParams {
        int256 tradersNetVolume;
        int256 price;
        int256 multiplier;
        int256 curCost;
        int256 fee;
        int256 realizedCost;
        int256 protocolFee;
    }

    function _trade(address account, int256 tradeVolume) internal _lock_ {
        (int256 totalDynamicEquity, int256 totalAbsCost) = _updateSymbolPricesAndFundingRates();
        (IPTokenLite.Position memory position, int256 margin) = _settleTraderFundingFee(account);

        TradeParams memory params;

        params.tradersNetVolume = _symbol.tradersNetVolume;
        params.price = _symbol.price;
        params.multiplier = _protocolParameters.futuresMultiplier();
        params.curCost = (((tradeVolume * params.price) / ONE) * params.multiplier) / ONE;
        params.fee = (params.curCost.abs() * _protocolParameters.futuresFeeRatio()) / ONE;

        if (!(position.volume >= 0 && tradeVolume >= 0) && !(position.volume <= 0 && tradeVolume <= 0)) {
            int256 absVolume = position.volume.abs();
            int256 absTradeVolume = tradeVolume.abs();
            if (absVolume <= absTradeVolume) {
                // previous position is totally closed
                params.realizedCost = (params.curCost * absVolume) / absTradeVolume + position.cost;
            } else {
                // previous position is partially closed
                params.realizedCost = (position.cost * absTradeVolume) / absVolume + params.curCost;
            }
        }

        // adjust totalAbsCost after trading
        totalAbsCost +=
            (((((params.tradersNetVolume + tradeVolume).abs() - params.tradersNetVolume.abs()) *
                params.price) / ONE) * params.multiplier) /
            ONE;

        position.volume += tradeVolume;
        position.cost += params.curCost - params.realizedCost;
        position.lastCumulativeFundingRate = _symbol.cumulativeFundingRate;
        margin -= params.fee + params.realizedCost;

        _symbol.tradersNetVolume += tradeVolume;
        _symbol.tradersNetCost += params.curCost - params.realizedCost;
        params.protocolFee = (params.fee * _protocolParameters.protocolFeeCollectRatio()) / ONE;
        _protocolFeeAccrued += params.protocolFee;
        _liquidity += params.fee - params.protocolFee + params.realizedCost;

        require(
            totalAbsCost == 0 ||
                (totalDynamicEquity * ONE) / totalAbsCost >= _protocolParameters.minPoolMarginRatio(),
            "PerpetualPool: insufficient liquidity"
        );
        require(
            _getTraderMarginRatio(position, margin) >= _protocolParameters.minInitialMarginRatio(),
            "PerpetualPool: insufficient margin"
        );

        _updateTraderPortfolio(account, position, margin);

        emit Trade(account, tradeVolume, params.price.itou());
    }

    function _liquidate(address liquidator, address account) internal _lock_ {
        _updateSymbolPricesAndFundingRates();
        (IPTokenLite.Position memory position, int256 margin) = _settleTraderFundingFee(account);
        require(
            _getTraderMarginRatio(position, margin) < _protocolParameters.minMaintenanceMarginRatio(),
            "PerpetualPool: cannot liquidate"
        );

        int256 netEquity = margin;
        if (position.volume != 0) {
            _symbol.tradersNetVolume -= position.volume;
            _symbol.tradersNetCost -= position.cost;
            netEquity +=
                (((position.volume * _symbol.price) / ONE) * _protocolParameters.futuresMultiplier()) /
                ONE -
                position.cost;
        }

        int256 reward;
        int256 minLiquidationReward = _protocolParameters.minLiquidationReward();
        int256 maxLiquidationReward = _protocolParameters.maxLiquidationReward();
        if (netEquity <= minLiquidationReward) {
            reward = minLiquidationReward;
        } else if (netEquity >= maxLiquidationReward) {
            reward = maxLiquidationReward;
        } else {
            reward =
                ((netEquity - minLiquidationReward) * _protocolParameters.liquidationCutRatio()) /
                ONE +
                minLiquidationReward;
        }

        _liquidity += margin - reward;
        IPTokenLite(_pTokenAddress).burn(account);
        _transferOut(liquidator, reward.itou());

        emit Liquidate(account, liquidator, reward.itou());
    }

    //================================================================================
    // Helpers
    //================================================================================

    function _updateSymbolOracles(SignedPrice memory price) internal {
        IOracleWithUpdate(_protocolParameters.futuresOracleAddress()).updatePrice(
            _underlyingAddress,
            price.timestamp,
            price.price,
            price.v,
            price.r,
            price.s
        );
    }

    function _updateSymbolPricesAndFundingRates()
        internal
        returns (int256 totalDynamicEquity, int256 totalAbsCost)
    {
        uint256 preBlockNumber = _lastUpdateBlock;
        uint256 curBlockNumber = block.number;
        totalDynamicEquity = _liquidity;

        if (curBlockNumber > preBlockNumber) {
            _symbol.price = IOracle(_protocolParameters.futuresOracleAddress()).getPrice().utoi();
            console.log("_symbol.price");
        }
        if (_symbol.tradersNetVolume != 0) {
            int256 cost = (((_symbol.tradersNetVolume * _symbol.price) / ONE) *
                _protocolParameters.futuresMultiplier()) / ONE;
            totalDynamicEquity -= cost - _symbol.tradersNetCost;
            totalAbsCost += cost.abs();
        }

        if (curBlockNumber > preBlockNumber) {
            if (_symbol.tradersNetVolume != 0) {
                int256 ratePerBlock = (((((((((_symbol.tradersNetVolume * _symbol.price) / ONE) *
                    _symbol.price) / ONE) * _protocolParameters.futuresMultiplier()) / ONE) *
                    _protocolParameters.futuresMultiplier()) / ONE) *
                    _protocolParameters.futuresFundingRateCoefficient()) / totalDynamicEquity;
                int256 delta = ratePerBlock * int256(curBlockNumber - preBlockNumber);
                unchecked {
                    _symbol.cumulativeFundingRate += delta;
                }
            }
        }

        _lastUpdateBlock = curBlockNumber;
    }

    function getTraderPortfolio(address account)
        public
        view
        returns (IPTokenLite.Position memory position, int256 margin)
    {
        IPTokenLite pToken = IPTokenLite(_pTokenAddress);
        position = pToken.getPosition(account);
        margin = pToken.getMargin(account);
    }

    function _updateTraderPortfolio(
        address account,
        IPTokenLite.Position memory position,
        int256 margin
    ) internal {
        IPTokenLite pToken = IPTokenLite(_pTokenAddress);
        pToken.updatePosition(account, position);
        pToken.updateMargin(account, margin);
    }

    function _settleTraderFundingFee(address account)
        internal
        returns (IPTokenLite.Position memory position, int256 margin)
    {
        (position, margin) = getTraderPortfolio(account);
        int256 funding;
        if (position.volume != 0) {
            int256 cumulativeFundingRate = _symbol.cumulativeFundingRate;
            int256 delta;
            unchecked {
                delta = cumulativeFundingRate - position.lastCumulativeFundingRate;
            }
            funding += (position.volume * delta) / ONE;

            position.lastCumulativeFundingRate = cumulativeFundingRate;
        }
        if (funding != 0) {
            margin -= funding;
            _liquidity += funding;
        }
    }

    function _getTraderMarginRatio(IPTokenLite.Position memory position, int256 margin)
        internal
        view
        returns (int256)
    {
        int256 totalDynamicEquity = margin;
        int256 totalAbsCost;
        if (position.volume != 0) {
            int256 cost = (((position.volume * _symbol.price) / ONE) *
                _protocolParameters.futuresMultiplier()) / ONE;
            totalDynamicEquity += cost - position.cost;
            totalAbsCost += cost.abs();
        }
        return totalAbsCost == 0 ? type(int256).max : (totalDynamicEquity * ONE) / totalAbsCost;
    }

    function _deflationCompatibleSafeTransferFrom(
        address from,
        address to,
        uint256 bAmount
    ) internal returns (uint256) {
        IERC20 bToken = IERC20(_bTokenAddress);
        uint256 balance1 = bToken.balanceOf(to);
        bToken.safeTransferFrom(from, to, bAmount);
        uint256 balance2 = bToken.balanceOf(to);
        return balance2 - balance1;
    }

    function _transferIn(address from, uint256 bAmount) internal returns (uint256) {
        uint256 amount = _deflationCompatibleSafeTransferFrom(
            from,
            address(this),
            bAmount.rescale(18, _decimals)
        );
        return amount.rescale(_decimals, 18);
    }

    function _transferOut(address to, uint256 bAmount) internal {
        uint256 amount = bAmount.rescale(18, _decimals);
        uint256 leftover = bAmount - amount.rescale(_decimals, 18);
        // leftover due to decimal precision is accrued to _protocolFeeAccrued
        _protocolFeeAccrued += leftover.utoi();
        IERC20(_bTokenAddress).safeTransfer(to, amount);
    }

    // function migrationTimestamp() external view override returns (uint256) {
    //     // TODO: Implement
    // }

    // function migrationDestination() external view override returns (address) {
    //     // TODO: Implement
    // }

    // function prepareMigration(address target, uint256 graceDays) external override {
    //     // TODO: Implement
    // }

    // function approveMigration() external override {
    //     // TODO: Implement
    // }

    // function executeMigration(address source) override external {
    //     // TODO: Implement
    // }

    // function controller() external view override returns (address) {
    //     // TODO: Implement
    // }

    // function setNewController(address newController) external override {
    //     // TODO: Implement
    // }

    // function claimNewController() external override {
    //     // TODO: Implement
    // }
}
