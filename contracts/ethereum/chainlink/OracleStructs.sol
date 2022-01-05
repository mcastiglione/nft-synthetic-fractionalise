// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

struct APIOracleInfo {
    address linkToken;
    address chainlinkNode;
    string jobId;
    string booleanJobId;
    uint256 nodeFee;
}

struct VerifyRequest {
    address collection;
    uint256 tokenId;
}

struct ChangeRequest {
    address collection;
    uint256 tokenFrom;
    uint256 tokenTo;
    address caller;
}
