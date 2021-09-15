// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceData is Ownable {
    uint256 public bidOfferTimeLimit;
    uint256 public nftLockTime;
    uint256 public tradingFee;
    
    /**
     * @dev set initial state of the data
     */
    constructor(
        uint256 _bidOfferTimeLimit,
        uint256 _nftLockTime,
        uint256 _tradingFee
    ) {
        bidOfferTimeLimit = _bidOfferTimeLimit;
        nftLockTime = _nftLockTime;
        tradingFee = _tradingFee;
    }

    function setBidOfferTimeLimit(uint256 _bidOfferTimeLimit) external onlyOwner {
        bidOfferTimeLimit = _bidOfferTimeLimit;
    }

    function setNftLockTime(uint256 _nftLockTime) external onlyOwner {
        nftLockTime = _nftLockTime;
    }

    function setTradingFee(uint256 _tradingFee) external onlyOwner {
        tradingFee = _tradingFee;
    }

    function getParameters()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (
            bidOfferTimeLimit,
            nftLockTime,
            tradingFee
        );
    }
}
