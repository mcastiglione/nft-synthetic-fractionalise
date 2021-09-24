// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../implementations/SyntheticCollectionManager.sol";

/**
 * @dev the ownership will be transferred after deploy to the router contract
 */
contract RandomNumberConsumerMock is Ownable {
    mapping(address => bool) private _whitelistedCollections;

    event RequestedRandomness(bytes32 requestId, address fromCollection);

    /**
     * @dev constructor inherits VRFConsumerBase
     */
    constructor() {} // solhint-disable-line

    /**
     * @dev mock just for testing purposes
     */
    function getRandomNumber() external returns (bytes32 requestId) {
        require(_whitelistedCollections[msg.sender], "Invalid requester");

        requestId = keccak256(abi.encodePacked("requestId"));

        fulfillRandomnessMock(requestId, 131, msg.sender);
    }

    /**
     * @dev mock just for testing purposes
     */
    function fulfillRandomnessMock(
        bytes32 requestId,
        uint256 randomness,
        address collection
    ) public {
        SyntheticCollectionManager(collection).processFlipResult(randomness % 2, requestId);
    }

    /**
     * @dev whitelist collections to get random from this contract
     */
    function whitelistCollection(address collectionId) external onlyOwner {
        _whitelistedCollections[collectionId] = true;
    }
}
