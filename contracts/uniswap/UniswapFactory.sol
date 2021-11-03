// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import "@uniswap/v2-core/contracts/UniswapV2Factory.sol";

contract UniswapFactory is UniswapV2Factory {
    constructor() UniswapV2Factory(msg.sender) public {}
}