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
     * @dev nonce to count the changes of an original collection token id
     *      in order to avoid double change (with the second one keeping the synthetic playing)
     */
    mapping(address => mapping(uint256 => uint256)) public changeNonces;

    /**
     * @dev tokens in this map can be retrieved by the owner (address returned)
     */
    mapping(address => mapping(uint256 => address)) public pendingWithdraws;

    address private _validatorOracleAddress;

    event UnlockRequested(address collection, uint256 tokenId);
    event ChangeRequested(address collection, uint256 tokenFrom, uint256 tokenTo);
    event ChangeApproved(address collection, uint256 tokenFrom, uint256 tokenTo);
    event NFTUnlocked(address collection, uint256 tokenId, address newOwner);

    constructor(address validatorOracleAddress_) {
        _validatorOracleAddress = validatorOracleAddress_;

        _setupRole(VALIDATOR_ORACLE, validatorOracleAddress_);
        _setupRole(MANAGER, msg.sender);
    }

    function lockNFT(address collection_, uint256 tokenId_) external {
        require(_holdings[collection_][tokenId_] == address(0), "Token already locked");

        // get the token
        IERC721(collection_).transferFrom(msg.sender, address(this), tokenId_);

        // the sender must be the collection contract
        _holdings[collection_][tokenId_] = msg.sender;
    }

    function requestUnlock(address collection_, uint256 tokenId_) external {
        require(_holdings[collection_][tokenId_] != address(0), "Token not locked");
        require(pendingWithdraws[collection_][tokenId_] == address(0), "Already withdrawable");

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

    function requestChange(
        address collection_,
        uint256 tokenFrom_,
        uint256 tokenTo_
    ) external {
        require(_holdings[collection_][tokenFrom_] != address(0), "Token not locked");
        require(_holdings[collection_][tokenTo_] == address(0), "Token already locked");
        require(pendingWithdraws[collection_][tokenFrom_] == address(0), "Withdrawable token");

        // get the token
        IERC721(collection_).transferFrom(msg.sender, address(this), tokenTo_);

        ETHValidatorOracle(_validatorOracleAddress).verifyTokenIsChangeable(
            collection_,
            tokenFrom_,
            tokenTo_,
            msg.sender,
            changeNonces[collection_][tokenFrom_]
        );

        emit ChangeRequested(collection_, tokenFrom_, tokenTo_);
    }

    function changeNFTs(
        address collection_,
        uint256 tokenFrom_,
        uint256 tokenTo_,
        address owner_
    ) external onlyRole(VALIDATOR_ORACLE) {
        // release the space
        _holdings[collection_][tokenFrom_] = address(0);
        _holdings[collection_][tokenTo_] = owner_;

        // increment the nonce
        changeNonces[collection_][tokenFrom_] += 1;

        // transfer the token
        IERC721(collection_).transferFrom(address(this), owner_, tokenFrom_);

        emit ChangeApproved(collection_, tokenFrom_, tokenTo_);
    }

    /**
     * @notice check if the vault holds a token
     */
    function isTokenInVault(address collection_, uint256 tokenId_) external view returns (bool) {
        address previousOwner = _holdings[collection_][tokenId_];
        return previousOwner != address(0);
    }

    function withdraw(address collection_, uint256 tokenId_) external {
        require(pendingWithdraws[collection_][tokenId_] == msg.sender, "You can not withdraw this token");

        // remove pending withdrawal
        pendingWithdraws[collection_][tokenId_] = address(0);

        // release the space
        _holdings[collection_][tokenId_] = address(0);

        // increment the nonce
        nonces[collection_][tokenId_] += 1;

        // transfer the token
        IERC721(collection_).transferFrom(address(this), msg.sender, tokenId_);
    }
}
