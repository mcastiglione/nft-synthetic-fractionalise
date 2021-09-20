// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Interfaces.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract FlipCoinGenerator is IFlipCoinGenerator, VRFConsumerBase {
    bytes32 private keyHash;
    uint256 private fee;
    uint256 private randomSeed;

    constructor(address coordinator, address link) VRFConsumerBase(coordinator, link) {}

    function generateRandom() external view override returns (uint8) {
        return 0;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {}
}
