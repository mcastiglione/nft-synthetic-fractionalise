// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../Interfaces.sol";

contract MockFlipCoinGenerator is IFlipCoinGenerator {
    uint8 private _random;

    function generateRandom() external view override returns (uint8) {
        return _random;
    }

    function setRandom(uint8 rand) external {
        _random = rand;
    }
}
