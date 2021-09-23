// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract PerpetualPoolLiteMock  {


    constructor() {} 

    function addSymbol(
        uint256 symbolId,
        string memory symbol,
        address oracleAddress,
        uint256 multiplier,
        uint256 feeRatio,
        uint256 fundingRateCoefficient
    ) public {
        uint256 a = 1;
    }

}
