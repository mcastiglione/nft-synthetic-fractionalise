// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IGovernanceData {
    function bidOfferTimeLimit() external view returns (uint256);

    function nftLockTime() external view returns (uint256);

    function tradingFee() external view returns (uint256);

    function getParameters()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );
}
