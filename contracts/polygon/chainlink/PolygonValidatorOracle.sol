// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../implementations/SyntheticCollectionManager.sol";
import "./OracleStructs.sol";

/**
 * @dev the ownership will be transferred after deployment to the router contract
 */
contract PolygonValidatorOracle is ChainlinkClient, Ownable {
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

    constructor(APIOracleInfo memory _oracleInfo) {
        linkToken = _oracleInfo.linkToken;
        chainlinkNode = _oracleInfo.chainlinkNode;
        jobId = stringToBytes32(_oracleInfo.jobId);
        nodeFee = (_oracleInfo.nodeFee * LINK_DIVISIBILITY) / 1000;
        apiURL = "SHOULD BE DEPLOYED YET";

        setChainlinkToken(linkToken);
    }

    function verifyTokenInCollection(address ethereumCollection, uint256 tokenId)
        external
        returns (bytes32 requestId)
    {
        require(_whitelistedCollections[msg.sender], "Invalid requester");

        Chainlink.Request memory request = buildChainlinkRequest(
            jobId,
            address(this),
            this.processResponse.selector
        );

        // set the request params
        Chainlink.add(
            request,
            "get",
            string(
                abi.encodePacked(apiURL, "collection=", ethereumCollection, "&tokenId=", uint2str(tokenId))
            )
        );
        Chainlink.add(request, "path", "locked");

        // Send the request
        requestId = sendChainlinkRequestTo(chainlinkNode, request, nodeFee);

        _verifyRequests[requestId] = VerifyRequest({
            tokenId: tokenId,
            originalCollection: ethereumCollection,
            syntheticCollection: msg.sender
        });
    }

    function processResponse(bytes32 requestId, bool verified) public recordChainlinkFulfillment(requestId) {
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

    function stringToBytes32(string memory source) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            result := mload(add(source, 32))
        }
    }

    function uint2str(uint256 _i) private pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
