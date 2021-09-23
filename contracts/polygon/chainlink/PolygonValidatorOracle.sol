// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "./OracleStructs.sol";

/**
 * @title oracle to get the assets price in USD
 * @author Eric Nordelo
 */
contract PolygonValidatorOracle is ChainlinkClient {
    // the token to get the price for
    string public token;

    // the url to get the prices
    string public apiURL;

    // the chainlink node
    address public chainlinkNode;

    // the node job id
    bytes32 public jobId;

    // the fee in LINK
    uint256 public nodeFee;

    // the address of the LINK token
    address public linkToken;

    constructor(OracleInfo memory _oracleInfo) {
        linkToken = _oracleInfo.linkToken;
        chainlinkNode = _oracleInfo.chainlinkNode;
        jobId = stringToBytes32(_oracleInfo.jobId);
        nodeFee = (_oracleInfo.nodeFee * LINK_DIVISIBILITY) / 1000;
        apiURL = "https://backend-exchange-oracle-prod.privi.store/past?";

        setChainlinkToken(linkToken);
    }

    function verifyTokenInCollection(address ethereumCollection, uint256 tokenId)
        external
        returns (bytes32 requestId)
    {
        // solhint-disable-next-line

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
                abi.encodePacked(apiURL, "&collection=", ethereumCollection, "&tokenId=", uint2str(tokenId))
            )
        );
        Chainlink.add(request, "path", "locked");

        // Send the request
        return sendChainlinkRequestTo(chainlinkNode, request, nodeFee);
    }

    function processResponse(bytes32 _requestId, bool verified)
        public
        recordChainlinkFulfillment(_requestId)
    {}

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
