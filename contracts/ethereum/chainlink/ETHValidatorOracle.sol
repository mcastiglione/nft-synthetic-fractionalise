// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../NFTVaultManager.sol";
import "./OracleStructs.sol";

contract ETHValidatorOracle is ChainlinkClient, Ownable, Initializable {
    /**
     * @dev oracle configuration parameters
     */
    string public token;
    string public apiURL;
    address public chainlinkNode;
    bytes32 public jobId;
    uint256 public nodeFee;
    address public linkToken;

    address private _vaultManagerAddress;

    mapping(bytes32 => VerifyRequest) private _verifyRequests;

    event ResponseReceived(bytes32 indexed requestId, address collection, uint256 tokenId, address newOwner);

    constructor(APIOracleInfo memory _oracleInfo) {
        linkToken = _oracleInfo.linkToken;
        chainlinkNode = _oracleInfo.chainlinkNode;
        jobId = stringToBytes32(_oracleInfo.jobId);
        nodeFee = (_oracleInfo.nodeFee * LINK_DIVISIBILITY) / 1000;
        apiURL = "SHOULD BE DEPLOYED YET";

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
     * @return requestId the id of the request to the Chainlink oracle
     */
    function verifyTokenIsWithdrawable(address collection, uint256 tokenId)
        external
        returns (bytes32 requestId)
    {
        Chainlink.Request memory request = buildChainlinkRequest(
            jobId,
            address(this),
            this.processResponse.selector
        );

        // set the request params
        Chainlink.add(
            request,
            "get",
            string(abi.encodePacked(apiURL, "?collection=", collection, "&tokenId=", uint2str(tokenId)))
        );
        Chainlink.add(request, "path", "withdrawable");

        // Send the request
        requestId = sendChainlinkRequestTo(chainlinkNode, request, nodeFee);

        _verifyRequests[requestId] = VerifyRequest({tokenId: tokenId, collection: collection});
    }

    /**
     * @dev function to process the oracle response (only callable from oracle)
     * @param requestId the id of the request to the Chainlink oracle
     * @param newOwner the address who can retrieve the nft (if 0 assumes is not withdrawable)
     */
    function processResponse(bytes32 requestId, address newOwner)
        public
        recordChainlinkFulfillment(requestId)
    {
        VerifyRequest memory requestData = _verifyRequests[requestId];

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
