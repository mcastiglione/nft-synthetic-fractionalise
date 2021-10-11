// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

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



contract UniswapPairMock is ERC20 {

    constructor() ERC20('UNISWAP V2 PAIR', 'LP') {}

    uint112 private _reserve0;
    uint112 private _reserve1;
    uint32 private _blockTimestampLast;

    function getReserves() public view
    returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    ) {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        blockTimestampLast = _blockTimestampLast;
    }

    function setReserves(
        address tokenA,
        address tokenB
    ) external {
        _reserve0 = uint112(IERC20(tokenA).balanceOf(address(this)));
        _reserve1 = uint112(IERC20(tokenB).balanceOf(address(this)));
    }

    function executeRemoveLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        address to
    ) external {
        IERC20(tokenA).transfer(to, amountADesired);
        IERC20(tokenB).transfer(to, amountBDesired);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
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
        amountA = amountADesired;
        amountB = amountBDesired;

        console.log('amountA', amountA);
        console.log('amountB', amountB);

        liquidity = sqrt(amountA*amountB);

        address pairAddress = UniSwapFactoryMock(_uniswapFactory).getPair(
            tokenA,
            tokenB
        );

        IERC20(tokenA).transferFrom(msg.sender, pairAddress, amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, pairAddress, amountBDesired);
        UniswapPairMock(pairAddress).setReserves(tokenA, tokenB);
        UniswapPairMock(pairAddress).mint(msg.sender, liquidity);

    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB) {
        amountA = amountAMin;
        amountB = amountBMin;
        address pairAddress = UniSwapFactoryMock(_uniswapFactory).getPair(
            tokenA,
            tokenB
        );

        UniswapPairMock(pairAddress).executeRemoveLiquidity(
            tokenA,
            tokenB,
            amountAMin,
            amountBMin,
            to
        );
    }


}
