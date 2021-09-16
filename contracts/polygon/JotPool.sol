// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract JotPool {
    using SafeERC20 for IERC20;

    uint256 public totalLiquidity;

    mapping(address => uint256) private liquidity;

    address public immutable jot;

    event LiquidityAdded(address provider, uint256 amount, uint256 mintedLiquidity);
    event LiquidityRemoved(address provider, uint256 amount, uint256 liquidityBurnt);

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
        emit LiquidityAdded(msg.sender, amount, mintedLiquidity);
        IERC20(jot).safeTransferFrom(msg.sender, address(this), amount);
    }

    function removeLiquidity(uint256 amount) external {
        require(liquidity[msg.sender] >= amount, "Remove amount exceeds balance");
        uint256 liquidityBurnt = (IERC20(jot).balanceOf(address(this)) * amount) / totalLiquidity;
        if (totalLiquidity - amount == 0) {
            liquidity[msg.sender] = 100;
            totalLiquidity = 100;
        } else {
            liquidity[msg.sender] -= amount;
            totalLiquidity -= amount;
        }

        emit LiquidityRemoved(msg.sender, amount, liquidityBurnt);

        IERC20(jot).safeTransfer(msg.sender, liquidityBurnt);
    }

    function balance() external view returns (uint256) {
        return liquidity[msg.sender];
    }
}
