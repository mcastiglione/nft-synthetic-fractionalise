// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../SyntheticProtocolRouter.sol";
import "../Interfaces.sol";
import "../libraries/ProtocolConstants.sol";
import "../governance/ProtocolParameters.sol";
import "./Structs.sol";
import "./Enums.sol";
import "hardhat/console.sol";

/*
 * funds pay by the owner on buyback events are sent to this contract
 */

contract RedemptionPool is AccessControl {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    bytes32 public constant ROUTER = keccak256("ROUTER");
    bytes32 public constant AUCTION_MANAGER = keccak256("AUCTION_MANAGER");
    bytes32 public constant RANDOM_ORACLE = keccak256("RANDOM_ORACLE");
    bytes32 public constant VALIDATOR_ORACLE = keccak256("VALIDATOR_ORACLE");

    /**
     * @dev mapping funds by jots contract
     */
    mapping(address => uint256) private _fundsByJotContract;

    /**
     * @notice the address of the Protocol Router
     */
    address public syntheticProtocolRouterAddress;

    /**
     * @notice the protocol parameters
     */
    ProtocolParameters public protocol;

    /**
     * @notice funding token address
     */
    address public fundingTokenAddress;

    /**
     * @notice events
     */

    event BuyBackFundsReceived(address indexed jotsContract, uint256 funds);


    constructor() {
    }

    function addRedemptionToPool(address jotContract_, uint256 funds_) public {
        _fundsByJotContract[jotContract_] = funds_;
        emit BuyBackFundsReceived(jotContract_, funds_);
    }

}
