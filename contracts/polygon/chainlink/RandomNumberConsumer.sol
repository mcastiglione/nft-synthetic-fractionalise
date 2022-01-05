// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../implementations/SyntheticCollectionManager.sol";

/**
 * @dev the ownership will be transferred after deployment to the router contract
 */
contract RandomNumberConsumer is VRFConsumerBase, Ownable {
    bytes32 internal immutable keyHash;
    uint256 internal immutable fee;

    mapping(bytes32 => address) private _requestIdToCollection;
    mapping(address => bool) private _whitelistedCollections;

    /**
     * @dev constructor inherits VRFConsumerBase
     */
    constructor(VRFOracleInfo memory _oracleInfo)
        VRFConsumerBase(_oracleInfo.vrfCoordinator, _oracleInfo.linkToken)
    {
        keyHash = _oracleInfo.keyHash;
        fee = _oracleInfo.vrfFee;
    }

    /**
     * @dev requests randomness
     */
    function getRandomNumber() external returns (bytes32 requestId) {
        require(_whitelistedCollections[msg.sender], "Invalid requester");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");

        requestId = requestRandomness(keyHash, fee);
        _requestIdToCollection[requestId] = msg.sender;
    }

    /**
     * @dev callback function used by VRF Coordinator (only 200k gas allowed and should not revert)
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        SyntheticCollectionManager(_requestIdToCollection[requestId]).processFlipResult(
            randomness % 2,
            requestId
        );
    }

    /**
     * @dev whitelist collections to get random from this contract
     */
    function whitelistCollection(address collectionId) external onlyOwner {
        _whitelistedCollections[collectionId] = true;
    }
}
