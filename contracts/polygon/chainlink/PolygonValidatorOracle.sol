// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../libraries/Stringify.sol";
import "../implementations/SyntheticCollectionManager.sol";
import "./OracleStructs.sol";
import "hardhat/console.sol";

/**
 * @dev the ownership will be transferred after deployment to the router contract
 */
contract PolygonValidatorOracle is ChainlinkClient, Ownable {
    using Stringify for uint256;
    using Stringify for address;
    using Stringify for string;

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

    mapping(bytes32 => VerifyRequest) private _verifyRequests;
    mapping(bytes32 => UpdateRequest) private _updateRequests;

    mapping(address => bool) private _whitelistedCollections;

    constructor(APIOracleInfo memory _oracleInfo) {
        linkToken = _oracleInfo.linkToken;
        chainlinkNode = _oracleInfo.chainlinkNode;
        booleanjobId = _oracleInfo.jobId.toBytes32();
        uint256JobId = _oracleInfo.uintJobId.toBytes32();
        nodeFee = _oracleInfo.nodeFee;
        apiURL = "https://nft-validator-o24ig.ondigitalocean.app/";

        setChainlinkToken(linkToken);
    }

    /**
     * @dev call to verify if a token is locked in ethereum vault,
     *      this method can be called only from the collection manager contract
     *
     * @param ethereumCollection the collection address in ethereum
     * @param tokenId the id of the nft in the synthetic collection
     * @param currentState the current state
     * @param nonce the nonce
     * @return requestId the id of the request to the Chainlink oracle
     */
    function verifyTokenInCollection(
        address ethereumCollection,
        uint256 tokenId,
        uint256 currentState,
        uint256 nonce
    ) external returns (bytes32 requestId) {
        require(_whitelistedCollections[msg.sender], "Invalid requester");

        Chainlink.Request memory request = buildChainlinkRequest(
            booleanjobId,
            address(this),
            this.processResponse.selector
        );

        // set the request params
        Chainlink.add(
            request,
            "get",
            string(
                abi.encodePacked(
                    apiURL,
                    "verify?collection=0x",
                    ethereumCollection.toString(),
                    "&tokenId=",
                    tokenId.toString(),
                    "&nonce=",
                    nonce.toString()
                )
            )
        );
        Chainlink.add(request, "path", "locked");

        // Send the request
        requestId = sendChainlinkRequestTo(chainlinkNode, request, nodeFee);

        _verifyRequests[requestId] = VerifyRequest({
            tokenId: tokenId,
            originalCollection: ethereumCollection,
            syntheticCollection: msg.sender,
            previousState: State(currentState)
        });
    }

    /**
     * @dev function to process the oracle response (only callable from oracle)
     * @param requestId the id of the request to the Chainlink oracle
     * @param verified wether the nft is locked or not on ethereum
     */
    function processResponse(bytes32 requestId, bool verified) public recordChainlinkFulfillment(requestId) {
        VerifyRequest memory requestData = _verifyRequests[requestId];

        SyntheticCollectionManager(requestData.syntheticCollection).processVerifyResponse(
            requestId,
            requestData,
            verified
        );
    }

    /**
     * @dev call to get the new buyback price
     *      this method can be called only from the collection manager contract
     *
     * @return requestId the id of the request to the Chainlink oracle
     */
    function updateBuybackPrice(address ethereumCollection) external returns (bytes32 requestId) {
        require(_whitelistedCollections[msg.sender], "Invalid requester");

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
        UpdateRequest memory requestData = _updateRequests[requestId];

        SyntheticCollectionManager(requestData.syntheticCollection).processBuybackPriceResponse(
            requestId,
            buybackPrice
        );
    }

    /**
     * @dev whitelist collections in order to allow calling this contract
     * (only router can whitelist after deploying the proxy, the router contract owns this one)
     * @param collectionId the collection manager (sythetic collection from polygon)
     */
    function whitelistCollection(address collectionId) external onlyOwner {
        _whitelistedCollections[collectionId] = true;
    }
}
