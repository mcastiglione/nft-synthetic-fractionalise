// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract UniswapPairMock {

    constructor() {}

    function getReserves() public view
    returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    ) {
        uint112 reserve0_ = 10000;
        uint112 reserve1_ = 10000;
        uint32 blockTimestampLast_ = 0;
        return (reserve0_, reserve1_, blockTimestampLast_);
    }
}

contract UniSwapFactoryMock {

    address private _uniswapPairAddress;

    constructor(address uniswapPairAddress) {
        _uniswapPairAddress = uniswapPairAddress;
    }

    function createPair(address tokenA, address tokenB) public returns (address) {
        return _uniswapPairAddress;
    }

    function getPair(address tokenA, address tokenB) public returns (address) {
        return _uniswapPairAddress;
    }

}

contract UniSwapRouterMock {

    address private _uniswapFactory;

    constructor(address uniswapFactory_) {
        _uniswapFactory = uniswapFactory_;
    }

    function factory() public view returns (address) {
        return _uniswapFactory;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public returns (
        uint256 amountA, 
        uint256 amountB, 
        uint256 liquidity
    ) {
        amountA = (amountADesired/100*90);
        amountB = (amountBDesired/100*90);
        liquidity = 0;
        return (amountA, amountB, liquidity);
    }
}
