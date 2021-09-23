// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Interfaces.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LinkManager {
    using SafeERC20 for IERC20;

    IUniswapV2Router01 immutable router;
    address private immutable matic;
    address private immutable link;
    address private immutable receiver;

    IUniswapV2Pair private immutable maticLinkPair;

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

        IUniswapV2Factory factory = IUniswapV2Factory(IUniswapV2Router01(quickswapRouter).factory());
        maticLinkPair = IUniswapV2Pair(factory.getPair(_link, _matic));
    }

    function swapToLink() external {
        (uint256 reserve0, uint256 reserve1, ) = maticLinkPair.getReserves();
        (uint256 reserveIn, uint256 reserveOut) = maticLinkPair.token0() == link
            ? (reserve1, reserve0)
            : (reserve0, reserve1);

        uint256 amountOut = router.getAmountOut(address(this).balance, reserveIn, reserveOut);

        address[] memory path = new address[](1);
        path[0] = link;
        router.swapExactETHForTokens{value: address(this).balance}(
            amountOut,
            path,
            receiver,
            block.timestamp
        );
    }
}
