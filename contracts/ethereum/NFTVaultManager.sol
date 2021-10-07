// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./chainlink/ETHValidatorOracle.sol";
import "./Structs.sol";

contract NFTVaultManager is AccessControl {
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

    /**
     * @dev tokens in this map can be changed
     */
    mapping(address => mapping(uint256 => PendingChange)) public pendingChanges;

    address private _validatorOracleAddress;

    event UnlockRequested(bytes32 indexed requestId, address collection, uint256 tokenId);
    event ChangeApproveRequested(
        bytes32 indexed requestId,
        address collection,
        uint256 tokenFrom,
        uint256 tokenTo
    );
    event ChangeResponseReceived(
        bytes32 indexed requestId,
        address collection,
        uint256 tokenFrom,
        uint256 tokenTo,
        bool response
    );
    event WithdrawResponseReceived(
        bytes32 indexed requestId,
        address collection,
        uint256 tokenId,
        address newOwner
    );

    constructor(address validatorOracleAddress_) {
        _validatorOracleAddress = validatorOracleAddress_;

        _setupRole(VALIDATOR_ORACLE, validatorOracleAddress_);
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

        bytes32 requestId = ETHValidatorOracle(_validatorOracleAddress).verifyTokenIsWithdrawable(
            collection_,
            tokenId_,
            nonces[collection_][tokenId_]
        );

        emit UnlockRequested(requestId, collection_, tokenId_);
    }

    function unlockNFT(
        bytes32 requestId_,
        address collection_,
        uint256 tokenId_,
        address newOwner
    ) external onlyRole(VALIDATOR_ORACLE) {
        // this condition is necessary to avoid double check and unlocking an nft that was already withdrawed
        if (_holdings[collection_][tokenId_] != address(0)) {
            if (newOwner != address(0)) {
                pendingWithdraws[collection_][tokenId_] = newOwner;
            }

            emit WithdrawResponseReceived(requestId_, collection_, tokenId_, newOwner);
        }
    }

    function requestChange(
        address collection_,
        uint256 tokenFrom_,
        uint256 tokenTo_
    ) external {
        require(_holdings[collection_][tokenFrom_] != address(0), "Token not locked");
        require(_holdings[collection_][tokenTo_] == address(0), "Token already locked");
        require(pendingWithdraws[collection_][tokenFrom_] == address(0), "Withdrawable token");
        require(pendingChanges[collection_][tokenFrom_].tokenTo == 0, "Change already approved");

        bytes32 requestId = ETHValidatorOracle(_validatorOracleAddress).verifyTokenIsChangeable(
            collection_,
            tokenFrom_,
            tokenTo_,
            msg.sender,
            changeNonces[collection_][tokenFrom_]
        );

        emit ChangeApproveRequested(requestId, collection_, tokenFrom_, tokenTo_);
    }

    function processChange(
        address collection_,
        uint256 tokenFrom_,
        uint256 tokenTo_,
        address owner_,
        bool changeable_,
        bytes32 requestId_
    ) external onlyRole(VALIDATOR_ORACLE) {
        // this condition is necessary to avoid double check and unlocking an nft that was already withdrawed
        if (
            _holdings[collection_][tokenFrom_] != address(0) && _holdings[collection_][tokenTo_] == address(0)
        ) {
            if (changeable_) {
                pendingChanges[collection_][tokenFrom_] = PendingChange({owner: owner_, tokenTo: tokenTo_});
            }

            emit ChangeResponseReceived(requestId_, collection_, tokenFrom_, tokenTo_, changeable_);
        }
    }

    /**
     * @notice check if the vault holds a token
     */
    function isTokenInVault(address collection_, uint256 tokenId_) external view returns (bool) {
        address previousOwner = _holdings[collection_][tokenId_];
        return previousOwner != address(0);
    }

    function change(
        address collection_,
        uint256 tokenFrom_,
        uint256 tokenTo_
    ) external {
        PendingChange memory pendingChange = pendingChanges[collection_][tokenFrom_];
        require(pendingChange.tokenTo == tokenTo_, "Non approved change");
        require(pendingChange.owner == msg.sender, "Only owner can change");

        // release the space
        delete _holdings[collection_][tokenFrom_];
        delete pendingChanges[collection_][tokenFrom_];

        _holdings[collection_][tokenTo_] = pendingChange.owner;

        // increment the nonce
        changeNonces[collection_][tokenFrom_] += 1;

        // transfer the tokens
        IERC721(collection_).transferFrom(msg.sender, address(this), tokenTo_);
        IERC721(collection_).transferFrom(address(this), msg.sender, tokenFrom_);
    }

    function withdraw(address collection_, uint256 tokenId_) external {
        require(pendingWithdraws[collection_][tokenId_] == msg.sender, "Non approved withdraw");

        // remove pending withdrawal
        delete pendingWithdraws[collection_][tokenId_];

        // release the space
        delete _holdings[collection_][tokenId_];

        // increment the nonce
        nonces[collection_][tokenId_] += 1;

        // transfer the token
        IERC721(collection_).transferFrom(address(this), msg.sender, tokenId_);
    }
}
