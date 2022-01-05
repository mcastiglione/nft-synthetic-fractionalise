// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./UniswapPairMock.sol";

function sqrt(uint y) pure returns (uint z) {
    if (y > 3) {
        z = y;
        uint x = y / 2 + 1;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    } else if (y != 0) {
        z = 1;
    }
}

contract UniSwapFactoryMock {
    address private _uniswapPairAddress;

    constructor(address uniswapPairAddress) {
        _uniswapPairAddress = uniswapPairAddress;
    }

    function createPair(address, address) public view returns (address) {
        return _uniswapPairAddress;
    }

    function getPair(address, address) public view returns (address) {
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
        uint256,
        uint256,
        address,
        uint256
    )
        public
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {

        address pairAddress = UniSwapFactoryMock(_uniswapFactory).getPair(tokenA, tokenB);

        (
            uint112 reserve0,
            , 
            
        ) =  UniswapPairMock(pairAddress).getReserves();

        amountA = amountBDesired;
        amountB = amountBDesired;

        liquidity = sqrt(amountA*amountB);

        IERC20(tokenA).transferFrom(msg.sender, pairAddress, amountA);
        IERC20(tokenB).transferFrom(msg.sender, pairAddress, amountB);
        UniswapPairMock(pairAddress).setReserves(tokenA, tokenB);
        UniswapPairMock(pairAddress).mint(msg.sender, liquidity);

    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256
    ) external returns (uint256 amountA, uint256 amountB) {
        address pairAddress = UniSwapFactoryMock(_uniswapFactory).getPair(tokenA, tokenB);
        
        (
            uint112 reserve0,
            uint112 reserve1, 
            
        ) =  UniswapPairMock(pairAddress).getReserves();

        uint256 totalSupply = UniswapPairMock(pairAddress).totalSupply();

        uint256 amountPerc = totalSupply/liquidity*100;

        amountA = reserve0/100*amountPerc;
        amountB = reserve1/100*amountPerc;

        UniswapPairMock(pairAddress).executeRemoveLiquidity(tokenA, tokenB, amountA, amountB, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {

        address tokenA = path[0];
        address tokenB = path[1];
        address pairAddress = UniSwapFactoryMock(_uniswapFactory).getPair(tokenA, tokenB);

        IERC20(tokenA).transferFrom(msg.sender, pairAddress, amountInMax);
        UniswapPairMock(pairAddress).executeSwap(tokenB, to, amountOut);

    }
}
