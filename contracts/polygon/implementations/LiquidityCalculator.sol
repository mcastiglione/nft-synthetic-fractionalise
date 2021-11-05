// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../governance/ProtocolParameters.sol";
import "./Structs.sol";
import "../Interfaces.sol";
import "hardhat/console.sol";
import "../Interfaces.sol";
import "./SyntheticCollectionManager.sol";

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

    
    /**
     * @dev helper for the execute buyback function
     */
    function getFundingLeftAndBuybackAmount(uint256 total_, uint256 fundingLiquidity_, uint256 JOT_SUPPLY, uint256 buybackPrice)
        external
        view
        returns (
            uint256 jotsLeft,
            uint256 fundingLeft,
            uint256 buybackAmount
        )
    {
        // Starting funding left
        fundingLeft = fundingLiquidity_;

        // If owner has enough balance buybackAmount is zero

        if (total_ > JOT_SUPPLY) {
            buybackAmount = 0;
            jotsLeft = total_ - JOT_SUPPLY;
        } else {
            // If owner has some funding tokens left
            if (fundingLeft > 0) {
                // How many jots you can buy with the funding tokens
                uint256 fundingToJots = (fundingLeft * buybackPrice) / 10**18;
                // if there's enough funding for buyback
                // then return 0 as buybackAmount and the remaining funding
                if ((fundingToJots + total_) > JOT_SUPPLY) {
                    uint256 remainingJots = total_ - JOT_SUPPLY;
                    uint256 requiredFunding = (remainingJots * buybackPrice) / 10**18;
                    fundingLeft -= requiredFunding;
                    buybackAmount = 0;
                }
                // if there isn't enough funding for buyback
                else {
                    buybackAmount = (JOT_SUPPLY - total_ - fundingToJots);
                    fundingLeft = 0;
                }
            } else {
                buybackAmount = ((JOT_SUPPLY - total_) * buybackPrice) / 10**18;
            }
        }
    }

}
