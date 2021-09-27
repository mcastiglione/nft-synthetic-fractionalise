// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../implementations/SyntheticCollectionManager.sol";
import "../chainlink/OracleStructs.sol";

/**
 * @dev the ownership will be transferred after deployment to the router contract
 */
contract PolygonValidatorOracleMock is ChainlinkClient, Ownable {
    mapping(bytes32 => VerifyRequest) private _verifyRequests;
    mapping(address => bool) private _whitelistedCollections;

    event ResponseReceived(
        bytes32 indexed requestId,
        address originalCollection,
        address syntheticCollection,
        uint256 tokenId,
        bool verified
    );

    // solhint-disable-next-line
    constructor() {}

    /**
     * @dev this is a mock just for testing purposes
     */
    function verifyTokenInCollection(
        address ethereumCollection,
        uint256 tokenId,
        uint256
    ) external returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked("requestId"));

        processResponseMock(requestId, true, ethereumCollection, msg.sender, tokenId);
    }

    /**
     * @dev this is a mock just for testing purposes
     */
    function processResponseMock(
        bytes32 requestId,
        bool verified,
        address originalCollection,
        address syntheticCollection,
        uint256 tokenId
    ) public {
        if (verified) {
            SyntheticCollectionManager(syntheticCollection).processSuccessfulVerify(tokenId);
        }

        emit ResponseReceived(requestId, originalCollection, syntheticCollection, tokenId, verified);
    }

    /**
     * @dev whitelist collections to call this contract
     */
    function whitelistCollection(address collectionId) external onlyOwner {
        _whitelistedCollections[collectionId] = true;
    }
}
