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
    string public token;
    string public apiURL;
    address public chainlinkNode;
    bytes32 public jobId;
    uint256 public nodeFee;
    address public linkToken;

    mapping(bytes32 => VerifyRequest) private _verifyRequests;
    mapping(address => bool) private _whitelistedCollections;

    event ResponseReceived(
        bytes32 indexed requestId,
        address originalCollection,
        address syntheticCollection,
        uint256 tokenId,
        bool verified
    );

    constructor() {}

    function processResponse(bytes32 requestId, bool verified) external {
        VerifyRequest memory requestData = _verifyRequests[requestId];

        if (verified) {
            SyntheticCollectionManager(requestData.syntheticCollection).processSuccessfulVerify(
                requestData.tokenId
            );
        }

        emit ResponseReceived(
            requestId,
            requestData.originalCollection,
            requestData.syntheticCollection,
            requestData.tokenId,
            verified
        );
    }

    /**
     * @dev whitelist collections to call this contract
     */
    function whitelistCollection(address collectionId) external onlyOwner {
        _whitelistedCollections[collectionId] = true;
    }
}
