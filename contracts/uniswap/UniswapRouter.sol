// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";

contract UniswapRouter is UniswapV2Router02 {
    constructor(
        address _factory,
        address _WETH
    ) UniswapV2Router02(
        _factory,
        _WETH
    ) public {}

    function getBlockTimestamp() external returns (
        uint256 blockNumber
    ) {
        blockNumber = block.timestamp;
    }
}