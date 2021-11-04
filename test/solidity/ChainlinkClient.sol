// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../contracts/libraries/Stringify.sol";
import "../../contracts/polygon/chainlink/OracleStructs.sol";

/**
 * @dev the ownership will be transferred after deployment to the router contract
 */
contract ChainlinkOracle is ChainlinkClient, Ownable {
    using Stringify for uint256;
    using Stringify for address;
    using Stringify for string;

    uint256 public buybackPriceGetter;

    /**
     * @dev oracle configuration parameters
     */
    string public token;
    string public apiURL;
    address public chainlinkNode;
    bytes32 public booleanjobId;
    bytes32 public uint256JobId;
    uint256 public nodeFee;
    address public linkToken;

    mapping(bytes32 => UpdateRequest) private _updateRequests;

    constructor(APIOracleInfo memory _oracleInfo) {
        linkToken = _oracleInfo.linkToken;
        chainlinkNode = _oracleInfo.chainlinkNode;
        booleanjobId = _oracleInfo.jobId.toBytes32();
        uint256JobId = _oracleInfo.uintJobId.toBytes32();
        nodeFee = _oracleInfo.nodeFee;
        apiURL = "https://nft-validator-hwk7x.ondigitalocean.app/";

        setChainlinkToken(linkToken);
    }

    /**
     * @dev call to get the new buyback price
     *      this method can be called only from the collection manager contract
     *
     * @return requestId the id of the request to the Chainlink oracle
     */
    function updateBuybackPrice(address ethereumCollection) external returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(
            uint256JobId,
            address(this),
            this.processBuybackPriceResponse.selector
        );

        // set the request params
        Chainlink.add(
            request,
            "get",
            string(abi.encodePacked(apiURL, "getprice?contractAddress=0x", ethereumCollection.toString()))
        );
        Chainlink.add(request, "path", "price");

        // Send the request
        requestId = sendChainlinkRequestTo(chainlinkNode, request, nodeFee);

        _updateRequests[requestId] = UpdateRequest({syntheticCollection: msg.sender});
    }

    /**
     * @dev function to process the oracle response (only callable from oracle)
     * @param requestId the id of the request to the Chainlink oracle
     * @param buybackPrice the new buyback price
     */
    function processBuybackPriceResponse(bytes32 requestId, uint256 buybackPrice)
        public
        recordChainlinkFulfillment(requestId)
    {
        buybackPriceGetter = buybackPrice;
    }
}
