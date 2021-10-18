// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Jot.sol";

/**
 * @notice funds pay by the owner on buyback events are sent to this contract
 * @author priviprotocol
 */
contract RedemptionPool is Initializable, AccessControl {
    bytes32 public constant MANAGER = keccak256("MANAGER");

    /// @notice the address of the jot corresponding token
    address public jotAddress;

    /// @notice the address of the funding token used
    address public fundingTokenAddress;

    /// @notice the address of the synthetic collection
    address public managerAddress;

    /// @notice the total value in funding token available to redeem
    uint256 public totalLiquidityToRedeeem;

    /// @notice the total value in jots available to redeem
    uint256 public jotsToRedeem;

    /// @dev the initializer modifier is to lock the implementation initialization
    constructor() initializer {} // solhint-disable-line

    /**
     * @dev initialize the proxy contract
     * @param jot_ the address of the jot corresponding token
     * @param fundingToken_ the address of the funding token
     */
    function initialize(
        address jot_,
        address fundingToken_,
        address syntheticCollection_
    ) external initializer {
        require(jot_ != address(0), "Invalid Jot token");
        require(fundingToken_ != address(0), "Invalid funding token");

        jotAddress = jot_;
        fundingTokenAddress = fundingToken_;
        managerAddress = syntheticCollection_;

        // setup the roles for the access control
        _setupRole(MANAGER, syntheticCollection_);
    }

    /**
     * @dev setter for redeemable values updates (only from collection manager)
     * @param liquidity_ the increase on redeemable liquidity
     * @param jots_ the increase on redeemable jots
     */
    function addRedemableBalance(uint256 liquidity_, uint256 jots_) external onlyRole(MANAGER) {
        totalLiquidityToRedeeem += liquidity_;
        jotsToRedeem += jots_;
    }

    /**
     * @notice allows to retrieve funding token from jots, to burn the supply left
     *         by buyback calls without enough owner supply
     *
     *         the user should approve the jots to be burned before calling this function
     *
     * @param amountOfJots_ the amount of jots to burn
     */
    function redeem(uint256 amountOfJots_) external {
        require(amountOfJots_ > 0, "Amount should be greater than 0");
        require(jotsToRedeem >= amountOfJots_, "Not enough tokens left");

        uint256 amountToGive = (totalLiquidityToRedeeem * amountOfJots_) / jotsToRedeem;

        totalLiquidityToRedeeem -= amountToGive;
        jotsToRedeem -= amountOfJots_;

        // transfer the funds and burn the jots
        IERC20(fundingTokenAddress).transfer(msg.sender, amountToGive);
        Jot(jotAddress).burnFrom(msg.sender, amountOfJots_);
    }
}
