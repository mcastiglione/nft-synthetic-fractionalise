// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../libraries/Stringify.sol";
import "../NFTVaultManager.sol";
import "./OracleStructs.sol";

contract ETHValidatorOracle is ChainlinkClient, Ownable, Initializable {
    using Stringify for uint256;
    using Stringify for address;

    /**
     * @dev oracle configuration parameters
     */
    string public token;
    string public apiURL;
    string public apiURLForChanges;
    address public immutable chainlinkNode;
    bytes32 public immutable jobId;
    bytes32 public immutable booleanJobId;
    uint256 public immutable nodeFee;
    address public linkToken;

    address private _vaultManagerAddress;

    mapping(bytes32 => VerifyRequest) private _verifyRequests;
    mapping(bytes32 => ChangeRequest) private _changeRequests;

    event ResponseReceived(bytes32 indexed requestId, address collection, uint256 tokenId, address newOwner);

    constructor(APIOracleInfo memory _oracleInfo) {
        linkToken = _oracleInfo.linkToken;
        chainlinkNode = _oracleInfo.chainlinkNode;
        jobId = stringToBytes32(_oracleInfo.jobId);
        booleanJobId = stringToBytes32(_oracleInfo.booleanJobId);
        nodeFee = _oracleInfo.nodeFee;
        apiURL = "https://nft-validator-hwk7x.ondigitalocean.app/iswithdrawable";
        apiURLForChanges = "https://nft-validator-hwk7x.ondigitalocean.app/ischangeable";

        setChainlinkToken(linkToken);
    }

    /**
     * @dev only owner can initialize, and the ownership is removed after that
     */
    function initialize(address _vault) external initializer onlyOwner {
        _vaultManagerAddress = _vault;
        renounceOwnership();
    }

    /**
     * @dev call to verify if a token is withdrawble in the synthetic collection,
     * this method can be called only from the nft vault contract
     * @param collection the collection address
     * @param tokenId the id of the nft in the collection
     * @param nonce the nonce
     * @return requestId the id of the request to the Chainlink oracle
     */
    function verifyTokenIsWithdrawable(
        address collection,
        uint256 tokenId,
        uint256 nonce
    ) external returns (bytes32 requestId) {
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
                abi.encodePacked(
                    apiURL,
                    "?collection=0x",
                    collection.toString(),
                    "&tokenId=",
                    tokenId.toString(),
                    "&nonce=",
                    nonce.toString()
                )
            )
        );
        Chainlink.add(request, "path", "withdrawable_by");

        // Send the request
        requestId = sendChainlinkRequestTo(chainlinkNode, request, nodeFee);

        _verifyRequests[requestId] = VerifyRequest({tokenId: tokenId, collection: collection});
    }

    /**
     * @dev call to verify if a token is changable in the synthetic collection,
     * this method can be called only from the nft vault contract
     * @param collection the collection address
     * @param tokenFrom the id of the nft in the collection to change from
     * @param tokenTo the id of the nft in the collection to change to
     * @param caller the caller
     * @param nonce the nonce
     * @return requestId the id of the request to the Chainlink oracle
     */
    function verifyTokenIsChangeable(
        address collection,
        uint256 tokenFrom,
        uint256 tokenTo,
        address caller,
        uint256 nonce
    ) external returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(
            booleanJobId,
            address(this),
            this.processResponseForChange.selector
        );

        // set the request params
        Chainlink.add(
            request,
            "get",
            string(
                abi.encodePacked(
                    apiURLForChanges,
                    "?collection=0x",
                    collection.toString(),
                    "&tokenFrom=",
                    tokenFrom.toString(),
                    "&tokenTo=",
                    tokenTo.toString(),
                    "&caller=",
                    caller.toString(),
                    "&nonce=",
                    nonce.toString()
                )
            )
        );
        Chainlink.add(request, "path", "is_changeable");

        // Send the request
        requestId = sendChainlinkRequestTo(chainlinkNode, request, nodeFee);

        _changeRequests[requestId] = ChangeRequest({
            tokenFrom: tokenFrom,
            collection: collection,
            tokenTo: tokenTo,
            caller: caller
        });
    }

    /**
     * @dev function to process the oracle response (only callable from oracle)
     * @param requestId the id of the request to the Chainlink oracle
     * @param newOwner_ the address who can retrieve the nft (if 0 assumes is not withdrawable)
     */
    function processResponse(bytes32 requestId, uint256 newOwner_)
        public
        recordChainlinkFulfillment(requestId)
    {
        VerifyRequest memory requestData = _verifyRequests[requestId];
        address newOwner = address(uint160(newOwner_));

        // only call the synthetic collection contract if is locked
        if (newOwner != address(0)) {
            NFTVaultManager(_vaultManagerAddress).unlockNFT(
                requestData.collection,
                requestData.tokenId,
                newOwner
            );
        }

        emit ResponseReceived(requestId, requestData.collection, requestData.tokenId, newOwner);
    }

    /**
     * @dev function to process the oracle response (only callable from oracle)
     * @param requestId the id of the request to the Chainlink oracle
     * @param changeable the response telling us if this tokens are changeable
     */
    function processResponseForChange(bytes32 requestId, bool changeable)
        public
        recordChainlinkFulfillment(requestId)
    {
        ChangeRequest memory requestData = _changeRequests[requestId];

        NFTVaultManager(_vaultManagerAddress).processChange(
            requestData.collection,
            requestData.tokenFrom,
            requestData.tokenTo,
            requestData.caller,
            changeable,
            requestId
        );
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
}
