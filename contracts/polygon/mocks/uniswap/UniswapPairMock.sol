// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UniswapPairMock is ERC20 {

    constructor() ERC20("UNISWAP V2 PAIR", "LP") {}

    uint112 private _reserve0;
    uint112 private _reserve1;
    uint32 private _blockTimestampLast;

    function getReserves()
        public
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        )
    {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        blockTimestampLast = _blockTimestampLast;
    }

    function setReserves(address tokenA, address tokenB) external {
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

    function executeSwap(address token, address to, uint256 amountOut) public {
        IERC20(token).transfer(to, amountOut);
    }
        
}