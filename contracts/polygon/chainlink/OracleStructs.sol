// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct OracleInfo {
    string appToken;
    address linkToken;
    address chainlinkNode;
    string jobId;
    uint256 nodeFee;
}
