// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
<<<<<<< HEAD
=======
import "./StakingERC721.sol";
>>>>>>> WIP
import "../governance/ProtocolParameters.sol";

contract JotPool is Initializable {
    using SafeERC20 for IERC20;

    uint256 public totalLiquidity;

    mapping(address => uint256) private liquidity;

    address public jot;

    ProtocolParameters private immutable protocol;

    event LiquidityAdded(address provider, uint256 amount, uint256 mintedLiquidity);
    event LiquidityRemoved(address provider, uint256 amount, uint256 liquidityBurnt);

    constructor(address _protocol) {
        require(_protocol != address(0), "Invalid protocol address");
        protocol = ProtocolParameters(_protocol);
    }

    function initialize(address _jot) external initializer {
        require(_jot != address(0), "Invalid Jot token");
        jot = _jot;
    }

    function addLiquidity(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        uint256 mintedLiquidity = totalLiquidity > 0
            ? (totalLiquidity * amount) / IERC20(jot).balanceOf(address(this))
            : 100;
        liquidity[msg.sender] += mintedLiquidity;
        totalLiquidity += mintedLiquidity;
        emit LiquidityAdded(msg.sender, amount, mintedLiquidity);
        IERC20(jot).safeTransferFrom(msg.sender, address(this), amount);
    }

    function removeLiquidity(uint256 amount) external {
        require(liquidity[msg.sender] >= amount, "Remove amount exceeds balance");
        uint256 liquidityBurnt = (IERC20(jot).balanceOf(address(this)) * amount) / totalLiquidity;
        if (totalLiquidity - amount > 0) {
            liquidity[msg.sender] -= amount;
            totalLiquidity -= amount;
        } else {
            uint256 jots = protocol.jotsSupply();
            liquidity[msg.sender] = jots;
            totalLiquidity = jots;
        }

        emit LiquidityRemoved(msg.sender, amount, liquidityBurnt);

        IERC20(jot).safeTransfer(msg.sender, liquidityBurnt);
    }

    function balance() external view returns (uint256) {
        return liquidity[msg.sender];
    }

    uint256 lastReward;
    uint256 cumulativeRevenue;
    uint256 totalShares;
    uint256 totalStaked;

    uint256 stakerShare;
    uint256 stakerShareDenominator;

    address nftAddress;

    function stakeShares(uint256 amount) external {
        require(IERC20(jot).balanceOf(msg.sender) >= amount, "Insufficient copyright fraction balance");
        uint256 balance = IERC20(jot).balanceOf(address(this));
        uint256 x = balance - lastReward;
        if (totalStaked != 0) {
            totalShares += ((x * stakerShare) * 10**18) / (totalStaked * stakerShareDenominator);
        }
        cumulativeRevenue += x;
        lastReward = balance;
        totalStaked += amount;
        StakingERC721(nftAddress).createPosition(msg.sender, amount, totalShares);
        IERC20(jot).safeTransferFrom(msg.sender, address(this), amount);
    }
}
