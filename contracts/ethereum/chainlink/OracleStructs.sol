// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct APIOracleInfo {
    address linkToken;
    address chainlinkNode;
    string jobId;
    uint256 nodeFee;
}

struct VerifyRequest {
    address collection;
    uint256 tokenId;
}