// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract JotPool {
    using SafeERC20 for IERC20;

    uint256 public totalLiquidity;

    mapping(address => uint256) private liquidity;

    address public immutable jot;

    constructor(address _jot) {
        jot = _jot;
    }

    function addLiquidity(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        uint256 mintedLiquidity = totalLiquidity == 0
            ? 100
            : (totalLiquidity * amount) / IERC20(jot).balanceOf(address(this));
        liquidity[msg.sender] += mintedLiquidity;
        totalLiquidity += mintedLiquidity;
        IERC20(jot).safeTransferFrom(msg.sender, address(this), amount);
    }

    function removeLiquidity(uint256 amount) external {
        require(liquidity[msg.sender] >= amount, "Insufficient balance");
        uint256 burntLiquidity = (IERC20(jot).balanceOf(address(this)) * liquidity[msg.sender]) /
            totalLiquidity;
        liquidity[msg.sender] -= amount;
        totalLiquidity -= amount;
        IERC20(jot).safeTransfer(msg.sender, burntLiquidity);
    }
}
