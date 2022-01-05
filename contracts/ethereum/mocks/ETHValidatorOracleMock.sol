// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../chainlink/OracleStructs.sol";
import "../NFTVaultManager.sol";

contract ETHValidatorOracleMock is ChainlinkClient, Ownable, Initializable {
    address private _vaultManagerAddress;

    mapping(bytes32 => VerifyRequest) private _verifyRequests;
    mapping(bytes32 => ChangeRequest) private _changeRequests;

    uint256 public verifyResponse;
    bool public changeResponse;

    /**
     * @dev only owner can initialize, and the ownership is removed after that
     */
    function initialize(address _vault) external initializer onlyOwner {
        _vaultManagerAddress = _vault;
        renounceOwnership();
    }

    function setVerifyResponse(uint256 response) external {
        verifyResponse = response;
    }

    function setChangeResponse(bool response) external {
        changeResponse = response;
    }

    /**
     * @dev call to verify if a token is withdrawble in the synthetic collection,
     *      this method can be called only from the nft vault contract
     *
     * @return requestId the id of the request to the Chainlink oracle
     */
    function verifyTokenIsWithdrawable(
        address collection_,
        uint256 tokenId_,
        uint256
    ) external returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked("requestId"));

        _verifyRequests[requestId] = VerifyRequest({tokenId: tokenId_, collection: collection_});

        processResponseMock(requestId, verifyResponse);
    }

    function verifyTokenIsChangeable(
        address collection_,
        uint256 tokenFrom_,
        uint256 tokenTo_,
        address caller_,
        uint256
    ) external returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked("requestId"));

        _changeRequests[requestId] = ChangeRequest({
            tokenFrom: tokenFrom_,
            collection: collection_,
            tokenTo: tokenTo_,
            caller: caller_
        });

        processChangeResponseMock(requestId, changeResponse);
    }

    /**
     * @dev function to process the oracle response (only callable from oracle)
     * @param requestId_ the id of the request to the Chainlink oracle
     * @param newOwner_ the address who can retrieve the nft (if 0 assumes is not withdrawable)
     */
    function processResponseMock(bytes32 requestId_, uint256 newOwner_) public {
        VerifyRequest memory requestData = _verifyRequests[requestId_];
        address newOwner = address(uint160(newOwner_));

        // only call the synthetic collection contract if is locked
        NFTVaultManager(_vaultManagerAddress).processUnlockResponse(
            requestId_,
            requestData.collection,
            requestData.tokenId,
            newOwner
        );
    }

    /**
     * @dev function to process the oracle response (only callable from oracle)
     * @param requestId_ the id of the request to the Chainlink oracle
     * @param changeable_ if the tokens are changeable
     */
    function processChangeResponseMock(bytes32 requestId_, bool changeable_) public {
        ChangeRequest memory requestData = _changeRequests[requestId_];

        NFTVaultManager(_vaultManagerAddress).processChangeResponse(
            requestData.collection,
            requestData.tokenFrom,
            requestData.tokenTo,
            requestData.caller,
            changeable_,
            requestId_
        );
    }
}
