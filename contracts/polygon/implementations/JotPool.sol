// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./StakingERC721.sol";
import "../governance/ProtocolParameters.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../libraries/ProtocolConstants.sol";

contract JotPool is ERC721, Initializable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    struct Position {
        uint256 id;
        uint256 liquidity;
        uint256 stake;
        uint256 totalShares;
    }

    address public jot;
    ProtocolParameters private immutable protocol;
    uint256 public totalLiquidity;

    string private _proxyName;
    string private _proxySymbol;

    uint256 public lastReward;
    uint256 public cumulativeRevenue;
    uint256 public totalShares;
    uint256 public totalStaked;

    uint256 public stakerShare = 10;
    uint256 public stakerShareDenominator = 1000;

    Counters.Counter private idGen;

    mapping(address => Position) private positions;

    event LiquidityAdded(address provider, uint256 amount, uint256 mintedLiquidity);
    event LiquidityRemoved(address provider, uint256 amount, uint256 liquidityBurnt);
    event Staked(address staker, uint256 amount, uint256 positionId);
    event Unstaked(address recipient, uint256 amount, uint256 reward);

    constructor(address _protocol) ERC721("", "") {
        require(_protocol != address(0), "Invalid protocol address");
        protocol = ProtocolParameters(_protocol);
    }

    function initialize(
        address _jot,
        string memory _name,
        string memory _symbol
    ) external initializer {
        require(_jot != address(0), "Invalid Jot token");
        jot = _jot;
        _proxyName = _name;
        _proxySymbol = _symbol;
    }

    function name() public view override returns (string memory) {
        return _proxyName;
    }

    function symbol() public view override returns (string memory) {
        return _proxySymbol;
    }

    function addLiquidity(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        uint256 mintedLiquidity = totalLiquidity > 0
            ? (totalLiquidity * amount) / IERC20(jot).balanceOf(address(this))
            : 100;
        positions[msg.sender].liquidity += mintedLiquidity;
        totalLiquidity += mintedLiquidity;
        emit LiquidityAdded(msg.sender, amount, mintedLiquidity);
        IERC20(jot).safeTransferFrom(msg.sender, address(this), amount);
    }

    function removeLiquidity(uint256 amount) external {
        require(positions[msg.sender].liquidity >= amount, "Remove amount exceeds balance");
        uint256 liquidityBurnt = (IERC20(jot).balanceOf(address(this)) * amount) / totalLiquidity;
        if (totalLiquidity - amount > 0) {
            positions[msg.sender].liquidity -= amount;
            totalLiquidity -= amount;
        } else {
            uint256 jots = ProtocolConstants.JOT_SUPPLY;
            positions[msg.sender].liquidity = jots;
            totalLiquidity = jots;
        }

        emit LiquidityRemoved(msg.sender, amount, liquidityBurnt);

        IERC20(jot).safeTransfer(msg.sender, liquidityBurnt);
    }

    function getPosition() external view returns (Position memory) {
        return positions[msg.sender];
    }

    function stakeShares(uint256 amount) external {
        require(IERC20(jot).balanceOf(msg.sender) >= amount, "Insufficient Jot balance");
        uint256 jotBalance = IERC20(jot).balanceOf(address(this));
        uint256 x = jotBalance - lastReward;
        if (totalStaked != 0) {
            totalShares += ((x * stakerShare) * 10**18) / (totalStaked * stakerShareDenominator);
        }
        cumulativeRevenue += x;
        lastReward = jotBalance;
        totalStaked += amount;
        address to = msg.sender;
        uint256 id = positions[to].id;
        if (id == 0) {
            idGen.increment();
            id = idGen.current();
            positions[to].id = id;
            _mint(to, id);
        }

        positions[to].stake = amount;
        positions[to].totalShares = totalShares;

        emit Staked(msg.sender, amount, id);

        IERC20(jot).safeTransferFrom(to, address(this), amount);
    }

    function unstakeShares(uint256 amount) external {
        require(positions[msg.sender].stake >= amount, "Insufficient stake balance");
        uint256 jotBalance = IERC20(jot).balanceOf(address(this));
        uint256 x = jotBalance - lastReward;
        if (totalStaked != 0) {
            totalShares += ((x * stakerShare) * 10**18) / (totalStaked * stakerShareDenominator);
        }

        address owner = msg.sender;
        uint256 reward = ((totalShares - positions[owner].totalShares) * positions[owner].stake) / 10**18;
        lastReward = IERC20(jot).balanceOf(address(this)) - reward;

        if (amount == positions[owner].stake) {
            _burn(positions[owner].id);
            delete positions[owner];
        } else {
            positions[owner].stake -= amount;
            positions[owner].totalShares = totalShares;
        }
        totalStaked -= amount;

        emit Unstaked(msg.sender, amount, reward);

        IERC20(jot).transfer(msg.sender, amount + reward);
    }

    function claimRewards() external {
        uint256 jotBalance = IERC20(jot).balanceOf(address(this));
        uint256 x = jotBalance - lastReward;
        if (totalStaked != 0) {
            totalShares += ((x * stakerShare) * 10**18) / (totalStaked * stakerShareDenominator);
        }

        address owner = msg.sender;
        uint256 reward = ((totalShares - positions[owner].totalShares) * positions[owner].stake) / 10**18;
        lastReward = IERC20(jot).balanceOf(address(this)) - reward;
        positions[owner].totalShares = totalShares;
    }
}
