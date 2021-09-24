// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct APIOracleInfo {
    address linkToken;
    address chainlinkNode;
    string jobId;
    uint256 nodeFee;
}

struct VRFOracleInfo {
    address vrfCoordinator;
    address linkToken;
    bytes32 keyHash;
    uint256 vrfFee;
}

struct VerifyRequest {
    address originalCollection;
    address syntheticCollection;
    uint256 tokenId;
}
