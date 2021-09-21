// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../implementations/SyntheticCollectionManager.sol";

/**
 * @dev the ownership will be transferred after deploy to the router contract
 */
contract RandomNumberConsumerMock is Ownable {
    mapping(bytes32 => address) private _requestIdToCollection;
    mapping(address => bool) private _whitelistedCollections;

    event RequestedRandomness(bytes32 requestId, address fromCollection);

    /**
     * @dev constructor inherits VRFConsumerBase
     */
    constructor() {} // solhint-disable-line

    /**
     * @dev requests randomness
     */
    function getRandomNumber() external returns (bytes32 requestId) {
        requestId = keccak256("MOCK");

        emit RequestedRandomness(requestId, msg.sender);
    }

    /**
     * @dev callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) external {
        SyntheticCollectionManager(_requestIdToCollection[requestId]).processFlipResult(
            randomness,
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
