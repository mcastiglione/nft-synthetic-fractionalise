// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
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
    address public fundingToken;
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
    event RewardsClaimed(address recipient, uint256 reward);

    constructor(address _protocol) ERC721("", "") {
        require(_protocol != address(0), "Invalid protocol address");
        protocol = ProtocolParameters(_protocol);
    }

    function initialize(
        address _jot,
        address _fundingToken,
        string memory _name,
        string memory _symbol
    ) external initializer {
        require(_jot != address(0), "Invalid Jot token");
        require(_fundingToken != address(0), "Invalid funding token");
        jot = _jot;
        fundingToken = _fundingToken;
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

        _stake(msg.sender, amount);

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

        _unstake(msg.sender, liquidityBurnt);

        IERC20(jot).safeTransfer(msg.sender, liquidityBurnt);
    }

    function getLiquidityValue(uint256 amount) external view returns (uint256) {
        return _getLiquidityValue(amount);
    }

    function getTotalLiquidityValue() external view returns (uint256) {
        return _getLiquidityValue(positions[msg.sender].liquidity);
    }

    function _getLiquidityValue(uint256 amount) internal view returns (uint256) {
        return (IERC20(jot).balanceOf(address(this)) * amount) / totalLiquidity;
    }

    function getPosition() external view returns (Position memory) {
        return positions[msg.sender];
    }

    function stakeShares(uint256 amount) external {
        require(IERC20(jot).balanceOf(msg.sender) >= amount, "Insufficient Jot balance");
        address to = msg.sender;
        _stake(to, amount);
        IERC20(jot).safeTransferFrom(to, address(this), amount);
    }

    function _stake(address to, uint256 amount) internal {
        (uint256 ftBalance, uint256 x) = _sync();
        cumulativeRevenue += x;
        lastReward = ftBalance;
        totalStaked += amount;

        uint256 id = positions[to].id;
        if (id == 0) {
            idGen.increment();
            id = idGen.current();
            positions[to].id = id;
            _mint(to, id);
        }

        positions[to].stake += amount;
        positions[to].totalShares = totalShares;

        emit Staked(msg.sender, amount, id);
    }

    function _sync() internal returns (uint256, uint256) {
        uint256 ftBalance = IERC20(fundingToken).balanceOf(address(this));
        uint256 x = ftBalance - lastReward;
        if (totalStaked != 0) {
            totalShares += ((x * stakerShare) * 10**18) / (totalStaked * stakerShareDenominator);
        }

        return (ftBalance, x);
    }

    function unstakeShares(uint256 amount) external {
        _unstake(msg.sender, amount);
        IERC20(jot).transfer(msg.sender, amount);
    }

    function _unstake(address to, uint256 amount) internal {
        require(positions[to].stake >= amount, "Insufficient stake balance");
        (uint256 ftBalance, ) = _sync();

        uint256 reward = _getReward(to);
        lastReward = ftBalance - reward;

        if (amount == positions[to].stake) {
            _burn(positions[to].id);
            delete positions[to];
        } else {
            positions[to].stake -= amount;
            positions[to].totalShares = totalShares;
        }
        totalStaked -= amount;

        emit Unstaked(msg.sender, amount, reward);

        IERC20(fundingToken).transfer(msg.sender, reward);
    }

    function claimRewards() external {
        (uint256 ftBalance, ) = _sync();

        address owner = msg.sender;
        uint256 reward = _getReward(owner);
        lastReward = ftBalance - reward;
        positions[owner].totalShares = totalShares;

        emit RewardsClaimed(msg.sender, reward);

        IERC20(fundingToken).transfer(msg.sender, reward);
    }

    function getReward() external view returns (uint256 reward) {
        reward = _getReward(msg.sender);
    }

    function _getReward(address owner) internal view returns (uint256 reward) {
        reward = ((totalShares - positions[owner].totalShares) * positions[owner].stake) / 10**18;
    }
}
