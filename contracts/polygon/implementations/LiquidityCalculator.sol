// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../governance/ProtocolParameters.sol";
import "./Structs.sol";
import "../Interfaces.sol";

contract LiquidityCalculator is AccessControl, Initializable {

    /// @notice role of the manager contract
    bytes32 public constant MANAGER = keccak256("MANAGER");

    address private _managerAddress;
    address private _swapAddress;
    address private _perpetualPoolLiteAddress;
    address private _fundingTokenAddress;
    address private _jotAddress;

    ProtocolParameters public protocol;

    constructor() {}

    function initialize(
        address managerAddress_,
        address swapAddress_,
        address protocol_,
        address perpetualPoolLiteAddress_,
        address fundingTokenAddress_,
        address jotAddress_
    ) external initializer {
        _managerAddress = managerAddress_;
        _swapAddress = swapAddress_;
        _perpetualPoolLiteAddress = perpetualPoolLiteAddress_;
        _fundingTokenAddress = fundingTokenAddress_;
        _jotAddress = jotAddress_;
        protocol = ProtocolParameters(protocol_);
    }


    function getAvailableFundingPerpetual(TokenData memory token) external view returns(uint256) {

        // Perpetual Pool and Uniswap liquidity percentages
        uint256 liquidityPerpetualPercentage = protocol.liquidityPerpetualPercentage();
        // Token funding tokens owned by nft owner
        uint256 liquiditySold = token.liquiditySold;
        // Amount in Funding that will go to PerpetualPoolLite
        uint256 perpetualFundingLiquidity = liquiditySold / 100 * liquidityPerpetualPercentage;

        return perpetualFundingLiquidity;
    }

    function getAccruedReward(address pairAddress, uint256 liquidityTokenBalance) external view returns(uint256 token0Reward, uint256 token1Reward) {
        IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(pairAddress);
        
        (
            uint112 reserve0,
            uint112 reserve1,
            
        ) =  uniswapV2Pair.getReserves();

        uint256 totalSupply = uniswapV2Pair.totalSupply();

        if (totalSupply == 0) {
            return (0, 0);
        }

        if (reserve0 == 0) {
            token0Reward = 0;
        } else {
            token0Reward = uint256(reserve0) / totalSupply * liquidityTokenBalance;
        }

        if(reserve1 == 0) {
            token1Reward = 0;
        } else {
            token1Reward = uint256(reserve1) / totalSupply * liquidityTokenBalance;
        }

    }

}
