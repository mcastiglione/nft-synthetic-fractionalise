// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../governance/ProtocolParameters.sol";
import "./Structs.sol";
import "../Interfaces.sol";

contract LiquidityManager is AccessControl, Initializable {

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


    function getAvailableFundingPerpetual(TokenData memory token) public view returns(uint256) {

        // Perpetual Pool and Uniswap liquidity percentages
        uint256 liquidityPerpetualPercentage = protocol.liquidityPerpetualPercentage();
        // Token funding tokens owned by nft owner
        uint256 liquiditySold = token.liquiditySold;
        // Amount in Funding that will go to PerpetualPoolLite
        uint256 perpetualFundingLiquidity = liquiditySold / 100 * liquidityPerpetualPercentage;

        return perpetualFundingLiquidity;
    }

    function getAvailableFundingUniswap(TokenData memory token) public view returns(
        uint256 jotsValue, uint256 fundingValue
    ) {
        // Perpetual Pool and Uniswap liquidity percentages
        uint256 liquidityUniswapPercentage = protocol.liquidityUniswapPercentage();
        // Token jots liquidity for Uniswap
        uint256 liquiditySupply = token.liquiditySupply;
        // Token funding tokens owned by nft owner
        uint256 liquiditySold = token.liquiditySold;

        jotsValue = (liquiditySupply / 100 * liquidityUniswapPercentage);
        fundingValue = (liquiditySold / 100 * liquidityUniswapPercentage);

    }

}
