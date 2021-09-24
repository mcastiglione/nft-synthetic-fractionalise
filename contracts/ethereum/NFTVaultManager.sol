// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTVaultManager is Ownable {
    /**
     * @notice the whitelist for the NFT collection addresses accpeted
     */
    mapping(address => bool) public approvedCollections;

    /**
     * @dev map to check if a holder has a token registered over an approved collection
     *
     *  COLLECTION_CONTRACT_ADDRESS => NFT_ID => HOLDER_ACCOUNT_ADDRESS OR ZERO_ADDRESS
     */
    mapping(address => mapping(uint256 => address)) private _holdings;

    function lockNFT(address collection_, uint256 tokenId_) external {
        require(approvedCollections[collection_], "Not approved collection");

        // this should be an invariant (can't receive a token that the contract is already holding)
        assert(_holdings[collection_][tokenId_] == address(0));

        // get the token
        IERC721(collection_).transferFrom(msg.sender, address(this), tokenId_);

        // the sender must be the collection contract
        _holdings[collection_][tokenId_] == msg.sender;
    }

    /**
     * @notice check if the vault holds a token
     */
    function isTokenInVault(address collection_, uint256 tokenId_) external view returns (bool) {
        require(approvedCollections[collection_], "Not approved collection");

        address previousOwner = _holdings[collection_][tokenId_];
        return previousOwner != address(0);
    }

    /**
     * @notice approve a collection contract
     */
    function approveCollection(address collection_) external onlyOwner {
        require(!approvedCollections[msg.sender], "Collection already approved");
        approvedCollections[collection_] = true;
    }

    /**
     * @notice use ERC-165 to check for IERC721 interface in the collection contract
     *         before approve
     */
    function safeApproveCollection(address collection_) external onlyOwner {
        bytes4 erc721interfaceId = type(IERC721).interfaceId;

        require(!approvedCollections[msg.sender], "Collection already approved");
        require(
            IERC165(collection_).supportsInterface(erc721interfaceId),
            "Address doesn't support IERC721 interface"
        );

        approvedCollections[collection_] = true;
    }
}
