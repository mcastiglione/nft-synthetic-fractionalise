// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../chainlink/OracleStructs.sol";
import "../NFTVaultManager.sol";
import "hardhat/console.sol";

contract ETHValidatorOracleMock is ChainlinkClient, Ownable, Initializable {
    address private _vaultManagerAddress;

    mapping(bytes32 => VerifyRequest) private _verifyRequests;
    mapping(bytes32 => ChangeRequest) private _changeRequests;

    uint256 public verifyResponse;
    bool public changeResponse;

    event ResponseReceived(bytes32 indexed requestId, address collection, uint256 tokenId, address newOwner);

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
     * this method can be called only from the nft vault contract
     * @return requestId the id of the request to the Chainlink oracle
     */
    function verifyTokenIsWithdrawable(
        address collection,
        uint256 tokenId,
        uint256
    ) external returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked("requestId"));

        _verifyRequests[requestId] = VerifyRequest({tokenId: tokenId, collection: collection});

        processResponseMock(requestId, verifyResponse);
    }

    function verifyTokenIsChangeable(
        address collection,
        uint256 tokenFrom,
        uint256 tokenTo,
        address caller,
        uint256
    ) external returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked("requestId"));

        _changeRequests[requestId] = ChangeRequest({
            tokenFrom: tokenFrom,
            collection: collection,
            tokenTo: tokenTo,
            caller: caller
        });

        processChangeResponseMock(requestId, changeResponse);
    }

    /**
     * @dev function to process the oracle response (only callable from oracle)
     * @param requestId the id of the request to the Chainlink oracle
     * @param newOwner_ the address who can retrieve the nft (if 0 assumes is not withdrawable)
     */
    function processResponseMock(bytes32 requestId, uint256 newOwner_) public {
        VerifyRequest memory requestData = _verifyRequests[requestId];
        address newOwner = address(uint160(newOwner_));

        console.log("The address is %s", newOwner);

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
     * @param changeable if the tokens are changeable
     */
    function processChangeResponseMock(bytes32 requestId, bool changeable) public {
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
}
