// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Interfaces.sol";

contract FlipCoinGenerator is IFlipCoinGenerator {
    function generateRandom() external override view returns (uint8) {
        return 0;
    }
}
