// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./StakingERC721.sol";

//TODO: add AccessControl
//TODO: add events
contract DistributionManager is Initializable {
    using SafeERC20 for IERC20;

    address public podFundingToken;
    address public podToken;
    address public jotToken;
    uint32 public stakerShare = 10;
    uint32 public stakerShareDenominator = 1000;

    uint256 public lastReward;
    uint256 public cumulativeRevenue;
    uint256 public totalCFStaked;
    uint256 public totalShares;

    address public copyrightFractionStakingNFT;
    address public podTokenStakingNFT;

    address private immutable cfStakingNFTBlueprint;
    address private immutable ptStakingNFTBlueprint;

    event CopyrightStaked();
    event CopyrightUnstaked();
    event CopyrightRewardsClaimed();

    event UnstakeReward(uint256 id, uint256 amount, uint256 reward);

    constructor(address cfNFTBluepring, address ptNFTBlueprint) {
        cfStakingNFTBlueprint = cfNFTBluepring;
        ptStakingNFTBlueprint = ptNFTBlueprint;
    }

    function initialize(
        address _podToken,
        address _podFundingToken,
        address _jotToken
    ) external initializer {
        require(_podToken != address(0), "Invalid pod token");
        require(_podFundingToken != address(0), "Invalid pod funding token");
        require(_jotToken != address(0), "Invalid copyright fraction token");

        podToken = _podToken;
        podFundingToken = _podFundingToken;
        copyrightFractionStakingNFT = Clones.clone(cfStakingNFTBlueprint);
        podTokenStakingNFT = Clones.clone(ptStakingNFTBlueprint);
    }

    //TODO: limit possibility to call stake/unstake/claim to owners of pod

    function stakeShares(uint256 amount) external {
        require(IERC20(jotToken).balanceOf(msg.sender) >= amount, "Insufficient copyright fraction balance");
        _syncStaking();
        totalCFStaked += amount;
        StakingERC721(copyrightFractionStakingNFT).createPosition(msg.sender, amount, totalShares);
        emit CopyrightStaked();
        IERC20(jotToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    function _syncStaking() internal {
        uint256 balance = IERC20(podFundingToken).balanceOf(address(this));
        uint256 x = balance - lastReward;
        _syncShares(x);
        cumulativeRevenue += x;
        lastReward = balance;
    }

    function _syncShares(uint256 x) private {
        if (totalCFStaked != 0) {
            totalShares += ((x * stakerShare) * 10**18) / (totalCFStaked * stakerShareDenominator);
        }
    }

    function unstakeShares(uint256 id, uint256 amount) external {
        require(
            StakingERC721(copyrightFractionStakingNFT).ownerOf(id) == msg.sender,
            "Cannot unstake on not owned position"
        );
        _syncShares(IERC20(podFundingToken).balanceOf(address(this)) - lastReward);
        _unstakeRewards(id, copyrightFractionStakingNFT, amount, totalShares);
        totalCFStaked -= amount;
        IERC20(jotToken).safeTransfer(msg.sender, amount);
    }

    function _unstakeRewards(
        uint256 id,
        address nft,
        uint256 amount,
        uint256 totalShares
    ) internal {
        uint256 reward = StakingERC721(nft).calculateReward(id, totalShares);
        lastReward = IERC20(podFundingToken).balanceOf(address(this)) - reward;
        StakingERC721(nft).decreasePosition(id, msg.sender, amount, totalShares);
        emit UnstakeReward(id, amount, reward);
        IERC20(podFundingToken).safeTransfer(msg.sender, reward);
    }

    function claimRewards(uint256 id) external {
        require(
            StakingERC721(copyrightFractionStakingNFT).ownerOf(id) == msg.sender,
            "Cannot claim rewards on not owned position"
        );
        _syncShares(IERC20(podFundingToken).balanceOf(address(this)) - lastReward);
        _claimRewards(id, copyrightFractionStakingNFT, totalShares);
    }

    function _claimRewards(
        uint256 id,
        address nft,
        uint256 totalShares
    ) internal {
        uint256 reward = StakingERC721(nft).calculateReward(id, totalShares);
        lastReward = IERC20(podFundingToken).balanceOf(address(this)) - reward;
        StakingERC721(nft).setPositionTotalShares(id, msg.sender, totalShares);
        IERC20(podFundingToken).safeTransfer(msg.sender, reward);
    }

    function getRewards(uint256 id) external view returns (uint256 reward) {
        reward = StakingERC721(copyrightFractionStakingNFT).calculateReward(id, totalShares);
    }

    function setStakerShare(uint32 newstakerShare, uint32 newstakerShareDenominator) external {
        require(newstakerShare <= newstakerShareDenominator, "Investor share exceeds 100%");
        stakerShare = newstakerShare;
        stakerShareDenominator = newstakerShareDenominator;
    }
}
