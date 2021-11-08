// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @dev collections struct
 */
struct SyntheticCollection {
    uint256 collectionID;
    address collectionManagerAddress;
    address jotAddress;
    address jotPoolAddress;
    address redemptionPoolAddress;
    address jotPairAddress;
    address syntheticNFTAddress;
    string originalName;
    string originalSymbol;
}

struct ProtocolParametersContracts {
    address fractionalizeProtocol;
    address futuresProtocol;
}

struct RegistrationMetadata {
    string originalName;
    string originalSymbol;
    string metadata;
}
