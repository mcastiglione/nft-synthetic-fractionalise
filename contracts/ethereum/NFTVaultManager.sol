// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./chainlink/ETHValidatorOracle.sol";

contract NFTVaultManager is AccessControl {
    bytes32 public constant MANAGER = keccak256("MANAGER");
    bytes32 public constant VALIDATOR_ORACLE = keccak256("VALIDATOR_ORACLE");

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

    /**
     * @dev the nonces allow to check if a token is safely withdrawable (avoid double verifying)
     */
    mapping(address => mapping(uint256 => uint256)) public nonces;

    /**
     * @dev tokens in this map can be retrieved by the owner (address returned)
     */
    mapping(address => mapping(uint256 => address)) public pendingWithdraws;

    address private _validatorOracleAddress;

    event UnlockRequested(address collection, uint256 tokenId);
    event NFTUnlocked(address collection, uint256 tokenId, address newOwner);

    constructor(address validatorOracleAddress_) {
        _validatorOracleAddress = validatorOracleAddress_;

        _setupRole(VALIDATOR_ORACLE, validatorOracleAddress_);
        _setupRole(MANAGER, msg.sender);
    }

    function lockNFT(address collection_, uint256 tokenId_) external {
        require(approvedCollections[collection_], "Not approved collection");
        require(_holdings[collection_][tokenId_] == address(0), "Token already locked");

        // get the token
        IERC721(collection_).transferFrom(msg.sender, address(this), tokenId_);

        // the sender must be the collection contract
        _holdings[collection_][tokenId_] = msg.sender;
    }

    function requestUnlock(address collection_, uint256 tokenId_) external {
        require(approvedCollections[collection_], "Not approved collection");
        require(_holdings[collection_][tokenId_] != address(0), "Token not locked");

        ETHValidatorOracle(_validatorOracleAddress).verifyTokenIsWithdrawable(
            collection_,
            tokenId_,
            nonces[collection_][tokenId_]
        );

        emit UnlockRequested(collection_, tokenId_);
    }

    function unlockNFT(
        address collection_,
        uint256 tokenId_,
        address newOwner
    ) external onlyRole(VALIDATOR_ORACLE) {
        pendingWithdraws[collection_][tokenId_] = newOwner;

        emit NFTUnlocked(collection_, tokenId_, newOwner);
    }

    /**
     * @notice check if the vault holds a token
     */
    function isTokenInVault(address collection_, uint256 tokenId_) external view returns (bool) {
        address previousOwner = _holdings[collection_][tokenId_];
        return approvedCollections[collection_] && previousOwner != address(0);
    }

    function withdraw(address collection_, uint256 tokenId_) external {
        require(pendingWithdraws[collection_][tokenId_] == msg.sender, "You can not withdraw this token");

        // release the space
        _holdings[collection_][tokenId_] = address(0);

        // increment the nonce
        nonces[collection_][tokenId_] += 1;

        // transfer the token
        IERC721(collection_).transferFrom(address(this), msg.sender, tokenId_);
    }

    /**
     * @notice approve a collection contract
     */
    function approveCollection(address collection_) external onlyRole(MANAGER) {
        require(!approvedCollections[msg.sender], "Collection already approved");
        approvedCollections[collection_] = true;
    }

    /**
     * @notice use ERC-165 to check for IERC721 interface in the collection contract
     *         before approve
     */
    function safeApproveCollection(address collection_) external onlyRole(MANAGER) {
        bytes4 erc721interfaceId = type(IERC721).interfaceId;

        require(!approvedCollections[msg.sender], "Collection already approved");
        require(
            IERC165(collection_).supportsInterface(erc721interfaceId),
            "Address doesn't support IERC721 interface"
        );

        approvedCollections[collection_] = true;
    }
}
