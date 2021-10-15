// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../libraries/Stringify.sol";
import "../NFTVaultManager.sol";
import "./OracleStructs.sol";

/**
 * @title Validator Oracle for withdraws and changes
 * @author priviprotocol
 * @notice use Chainlink API Get request to check if a locked
 *         token is withdrawable or if two locked token are
 *         interchangeable
 */
contract ETHValidatorOracle is ChainlinkClient, Ownable, Initializable {
    using Stringify for uint256;
    using Stringify for address;
    using Stringify for string;

    /// @notice the Chainlink node oracle address
    address public immutable chainlinkNode;

    /// @notice the job id for GET -> uint256
    bytes32 public immutable jobId;

    /// @notice the job id for GET -> bool
    bytes32 public immutable booleanJobId;

    /// @notice the node fee required by the Chainlink node
    uint256 public immutable nodeFee;

    /// @notice the API url to check withdrawable status
    string public apiURLForWithdraws;

    /// @notice the API url to check changeable status
    string public apiURLForChanges;

    /// @notice the address of the LINK token
    address public linkToken;

    /// @notice the address the vault contract
    address public vaultManagerAddress;

    mapping(bytes32 => VerifyRequest) private _verifyRequests;
    mapping(bytes32 => ChangeRequest) private _changeRequests;

    /**
     * @dev initialize the Chainlink client params
     * @param oracleInfo_ the struct with the oracle specifications
     */
    constructor(APIOracleInfo memory oracleInfo_) {
        chainlinkNode = oracleInfo_.chainlinkNode;
        nodeFee = oracleInfo_.nodeFee;

        // use the library to make the convertion
        jobId = oracleInfo_.jobId.toBytes32();
        booleanJobId = oracleInfo_.booleanJobId.toBytes32();

        apiURLForWithdraws = "https://nft-validator-hwk7x.ondigitalocean.app/iswithdrawable";
        apiURLForChanges = "https://nft-validator-hwk7x.ondigitalocean.app/ischangeable";

        linkToken = oracleInfo_.linkToken;
        setChainlinkToken(oracleInfo_.linkToken);
    }

    /**
     * @dev ensures that only the vault contract can request for verifications
     */
    modifier onlyVault() {
        require(vaultManagerAddress == msg.sender, "Only vault can request verifications");
        _;
    }

    /**
     * @dev only owner can initialize, and the ownership is removed after that
     * @param vault_ the address of the vault contract
     */
    function initialize(address vault_) external initializer onlyOwner {
        vaultManagerAddress = vault_;
        renounceOwnership();
    }

    /**
     * @dev call to verify if a token is withdrawble in the synthetic collection,
     *      this method can be called only from the nft vault contract
     *
     * @param collection_ the address of the nft collection
     * @param tokenId_ the id of the nft in the collection
     * @param nonce_ the nonce {see: NFTVaultManager}
     * @return requestId the id of the request to the Chainlink oracle
     */
    function verifyTokenIsWithdrawable(
        address collection_,
        uint256 tokenId_,
        uint256 nonce_
    ) external onlyVault returns (bytes32 requestId) {
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
                    apiURLForWithdraws,
                    "?collection=0x",
                    collection_.toString(),
                    "&tokenId=",
                    tokenId_.toString(),
                    "&nonce=",
                    nonce_.toString()
                )
            )
        );
        Chainlink.add(request, "path", "withdrawable_by");

        // send the request
        requestId = sendChainlinkRequestTo(chainlinkNode, request, nodeFee);

        // save the request params
        _verifyRequests[requestId] = VerifyRequest({tokenId: tokenId_, collection: collection_});
    }

    /**
     * @dev call to verify if a token is changable in the synthetic collection,
     *      this method can be called only from the nft vault contract
     *
     * @param collection_ the address of the nft collection
     * @param tokenFrom_ the id of the nft in the collection to change from
     * @param tokenTo_ the id of the nft in the collection to change to
     * @param caller_ the caller
     * @param nonce_ the nonce {see: NFTVaultManager}
     * @return requestId the id of the request to the Chainlink oracle
     */
    function verifyTokenIsChangeable(
        address collection_,
        uint256 tokenFrom_,
        uint256 tokenTo_,
        address caller_,
        uint256 nonce_
    ) external onlyVault returns (bytes32 requestId) {
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
                    collection_.toString(),
                    "&tokenFrom=",
                    tokenFrom_.toString(),
                    "&tokenTo=",
                    tokenTo_.toString(),
                    "&caller=",
                    caller_.toString(),
                    "&nonce=",
                    nonce_.toString()
                )
            )
        );
        Chainlink.add(request, "path", "is_changeable");

        // send the request
        requestId = sendChainlinkRequestTo(chainlinkNode, request, nodeFee);

        // save the request
        _changeRequests[requestId] = ChangeRequest({
            tokenFrom: tokenFrom_,
            collection: collection_,
            tokenTo: tokenTo_,
            caller: caller_
        });
    }

    /**
     * @dev function to process the oracle response (only callable from oracle)
     * @param requestId_ the id of the request to the Chainlink oracle
     * @param newOwner_ the address who can retrieve the nft (if 0 assumes is not withdrawable)
     */
    function processResponse(bytes32 requestId_, uint256 newOwner_)
        public
        recordChainlinkFulfillment(requestId_)
    {
        VerifyRequest memory requestData = _verifyRequests[requestId_];
        address newOwner = address(uint160(newOwner_));

        // only call the synthetic collection contract if is locked
        NFTVaultManager(vaultManagerAddress).unlockNFT(
            requestId_,
            requestData.collection,
            requestData.tokenId,
            newOwner
        );
    }

    /**
     * @dev function to process the oracle response (only callable from oracle)
     * @param requestId_ the id of the request to the Chainlink oracle
     * @param changeable_ the response telling us if this tokens are changeable
     */
    function processResponseForChange(bytes32 requestId_, bool changeable_)
        public
        recordChainlinkFulfillment(requestId_)
    {
        ChangeRequest memory requestData = _changeRequests[requestId_];

        NFTVaultManager(vaultManagerAddress).processChange(
            requestData.collection,
            requestData.tokenFrom,
            requestData.tokenTo,
            requestData.caller,
            changeable_,
            requestId_
        );
    }
}
