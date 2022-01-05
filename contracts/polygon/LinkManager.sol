// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./Interfaces.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LinkManager {
    using SafeERC20 for IERC20;

    IUniswapV2Router02 public immutable router;
    address public immutable matic;
    address public immutable link;
    address public immutable receiver;

    IUniswapV2Pair public immutable maticLinkPair;

    event Swapped(uint256[] amounts, address receiver);

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
        router = IUniswapV2Router02(quickswapRouter);
        matic = _matic;
        link = _link;
        receiver = _receiver;

        IUniswapV2Factory factory = IUniswapV2Factory(IUniswapV2Router02(quickswapRouter).factory());
        maticLinkPair = IUniswapV2Pair(factory.getPair(_link, _matic));
    }

    function swapToLink() external {
        address[] memory path = new address[](2);
        path[0] = matic;
        path[1] = link;
        uint256[] memory amounts = router.swapExactETHForTokens{value: address(this).balance}(
            0,
            path,
            receiver,
            // solhint-disable-next-line
            block.timestamp
        );

        emit Swapped(amounts, receiver);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // solhint-disable-next-line
    receive() external payable {}
}
