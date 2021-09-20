// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Interfaces.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LinkManager {
    IUniswapV2Router01 immutable router;
    address private immutable matic;
    address private immutable link;
    address private immutable receiver;

    constructor(
        address quickswapRouter,
        address _matic,
        address _link,
        address _receiver
    ) {
        require(quickswapRouter != address(0), "Invalid QuickSwap factory address");
        require(_matic != address(0), "Invalid Matic token address");
        require(_link != address(0), "Invalid LINK token address");
        require(_receiver != address(0), "Invalid receiver address");
        router = IUniswapV2Router01(quickswapRouter);
        matic = _matic;
        link = _link;
        receiver = _receiver;
    }

    function swapToLink() external {
        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(link, matic));
        uint256 linkBalance = IERC20(link).balanceOf(address(this));
        uint256 maticBalance = IERC20(matic).balanceOf(address(this));

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        (uint256 reserveIn, uint256 reserveOut) = pair.token0() == link
            ? (reserve1, reserve0)
            : (reserve0, reserve1);
        uint256 amountOut = router.getAmountOut(maticBalance, reserveIn, reserveOut);
        (uint256 amount0Out, uint256 amount1Out) = pair.token0() == link
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));

        IERC20(link).transfer(address(pair), linkBalance);
        pair.swap(amount0Out, amount1Out, receiver, new bytes(0));
    }
}
