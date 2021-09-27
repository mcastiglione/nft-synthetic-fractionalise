// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../chainlink/OracleStructs.sol";
import "../NFTVaultManager.sol";

contract ETHValidatorOracleMock is ChainlinkClient, Ownable, Initializable {
    address private _vaultManagerAddress;

    mapping(bytes32 => VerifyRequest) private _verifyRequests;

    event ResponseReceived(bytes32 indexed requestId, address collection, uint256 tokenId, address newOwner);

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
     * @return requestId the id of the request to the Chainlink oracle
     */
    function verifyTokenIsWithdrawable(address collection, uint256 tokenId)
        external
        returns (bytes32 requestId)
    {
        requestId = keccak256(abi.encodePacked("requestId"));
        _verifyRequests[requestId] = VerifyRequest({tokenId: tokenId, collection: collection});
        processResponseMock(requestId, address(this));
    }

    /**
     * @dev function to process the oracle response (only callable from oracle)
     * @param requestId the id of the request to the Chainlink oracle
     * @param newOwner the address who can retrieve the nft (if 0 assumes is not withdrawable)
     */
    function processResponseMock(bytes32 requestId, address newOwner)
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
}
