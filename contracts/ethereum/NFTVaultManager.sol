// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./chainlink/ETHValidatorOracle.sol";
import "./Structs.sol";

/**
 * @title the Vault where nfts are locked
 * @author priviprotocol
 */
contract NFTVaultManager is AccessControl {
    bytes32 public constant VALIDATOR_ORACLE = keccak256("VALIDATOR_ORACLE");

    /**
     * @dev map to check if a holder has a token registered over an approved collection
     *
     *  COLLECTION_CONTRACT_ADDRESS => NFT_ID => HOLDER_ACCOUNT_ADDRESS OR ZERO_ADDRESS
     */
    mapping(address => mapping(uint256 => address)) private _holdings;

    /**
     * @notice the nonces allow to check if a token is safely withdrawable (avoid double verifying)
     *         a user could try to withdraw a non registered token if nonces dont exist
     */
    mapping(address => mapping(uint256 => uint256)) public nonces;

    /**
     * @notice nonces to count the changes of an original collection token id
     *      in order to avoid double change (with the second one keeping the synthetic playing)
     */
    mapping(address => mapping(uint256 => uint256)) public changeNonces;

    /// @notice tokens in this map can be retrieved by the owner (address returned)
    mapping(address => mapping(uint256 => address)) public pendingWithdraws;

    /// @notice tokens in this map can be directly swapped
    mapping(address => mapping(uint256 => PendingChange)) public pendingChanges;

    /// @notice the address of the validator oracle
    address public validatorOracleAddress;

    /**
     * @dev emitted when owner of a locked token request a unlock
     * @param requestId the Chainlink oracle request id from the validator oracle
     * @param collection the address of the nft collection
     * @param tokenId the id of the nft token to unlock
     */
    event UnlockRequested(bytes32 indexed requestId, address collection, uint256 tokenId);

    /**
     * @dev emitted when the Chainlink oracle response for unlocking is received
     * @param requestId the Chainlink oracle request id from the validator oracle (to match)
     * @param collection the address of the nft collection
     * @param tokenId the id of the nft token to unlock
     * @param newOwner the address of the owner allowed to withdraw (if 0 assume is not withdrawable)
     */
    event WithdrawResponseReceived(
        bytes32 indexed requestId,
        address collection,
        uint256 tokenId,
        address newOwner
    );

    /**
     * @dev emitted when owner of a locked token request a change
     * @param requestId the Chainlink oracle request id from the validator oracle
     * @param collection the address of the nft collection
     * @param tokenFrom the id of the nft token to change (from)
     * @param tokenTo the id of the nft token to change (to)
     */
    event ChangeApproveRequested(
        bytes32 indexed requestId,
        address collection,
        uint256 tokenFrom,
        uint256 tokenTo
    );

    /**
     * @dev emitted when the Chainlink oracle response for a change is received
     * @param requestId the Chainlink oracle request id from the validator oracle (to match)
     * @param collection the address of the nft collection
     * @param tokenFrom the id of the nft token to change (from)
     * @param tokenTo the id of the nft token to change (to)
     * @param response wheter the tokens are changeable or not
     */
    event ChangeResponseReceived(
        bytes32 indexed requestId,
        address collection,
        uint256 tokenFrom,
        uint256 tokenTo,
        bool response
    );

    /**
     * @param validatorOracleAddress_ the address of the validator oracle (Chainlink client)
     */
    constructor(address validatorOracleAddress_) {
        validatorOracleAddress = validatorOracleAddress_;

        // set the role to fulfill requests
        _setupRole(VALIDATOR_ORACLE, validatorOracleAddress_);
    }

    /**
     * @notice call this method to lock an NFT in the vault (add it to the protocol)
     * @param collection_ the address of the nft collection
     * @param tokenId_ the nft token id
     */
    function lockNFT(address collection_, uint256 tokenId_) external {
        require(_holdings[collection_][tokenId_] == address(0), "Token already locked");

        // get the token
        IERC721(collection_).transferFrom(msg.sender, address(this), tokenId_);

        // the sender must be the collection contract
        _holdings[collection_][tokenId_] = msg.sender;
    }

    /**
     * @notice allows owner of locked tokens to request unlocking,
     *         validates the availability through the validator oracle
     *
     * @param collection_ the address of the nft collection
     * @param tokenId_ the nft token id
     */
    function requestUnlock(address collection_, uint256 tokenId_) external {
        require(_holdings[collection_][tokenId_] != address(0), "Token not locked");
        require(pendingWithdraws[collection_][tokenId_] == address(0), "Already withdrawable");

        bytes32 requestId = ETHValidatorOracle(validatorOracleAddress).verifyTokenIsWithdrawable(
            collection_,
            tokenId_,
            nonces[collection_][tokenId_]
        );

        emit UnlockRequested(requestId, collection_, tokenId_);
    }

    /**
     * @dev processes the oracle response for unlock requests
     * @param requestId_ the id of the Chainlink request
     * @param collection_ the address of the nft collection
     * @param tokenId_ the nft token id
     * @param newOwner_ the new owner (if 0, token is not withdrawable)
     */
    function processUnlockResponse(
        bytes32 requestId_,
        address collection_,
        uint256 tokenId_,
        address newOwner_
    ) external onlyRole(VALIDATOR_ORACLE) {
        // this condition is necessary to avoid double check and unlocking an nft that was already withdrawed
        // because of race condition among oracle request and fulfillment responses
        if (_holdings[collection_][tokenId_] != address(0)) {
            if (newOwner_ != address(0)) {
                pendingWithdraws[collection_][tokenId_] = newOwner_;
            }

            emit WithdrawResponseReceived(requestId_, collection_, tokenId_, newOwner_);
        }
    }

    /**
     * @notice allows owner of locked tokens to request changes,
     *         validates through the validator oracle
     *
     * @param collection_ the address of the nft collection
     * @param tokenFrom_ the nft token id to change (from)
     * @param tokenTo_ the nft token id to change (to)
     */
    function requestChange(
        address collection_,
        uint256 tokenFrom_,
        uint256 tokenTo_
    ) external {
        require(_holdings[collection_][tokenFrom_] != address(0), "Token not locked");
        require(_holdings[collection_][tokenTo_] == address(0), "Token already locked");
        require(pendingWithdraws[collection_][tokenFrom_] == address(0), "Withdrawable token");
        require(pendingChanges[collection_][tokenFrom_].tokenTo == 0, "Change already approved");

        bytes32 requestId = ETHValidatorOracle(validatorOracleAddress).verifyTokenIsChangeable(
            collection_,
            tokenFrom_,
            tokenTo_,
            msg.sender,
            changeNonces[collection_][tokenFrom_]
        );

        emit ChangeApproveRequested(requestId, collection_, tokenFrom_, tokenTo_);
    }

    /**
     * @dev processes the oracle response for change requests
     * @param collection_ the address of the nft collection
     * @param tokenFrom_ the nft token id to change (from)
     * @param tokenTo_ the nft token id to change (to)
     * @param owner_ the owner of the nfts
     * @param changeable_ the response, wheter is changeable or not
     * @param requestId_ the id of the Chainlink request
     */
    function processChangeResponse(
        address collection_,
        uint256 tokenFrom_,
        uint256 tokenTo_,
        address owner_,
        bool changeable_,
        bytes32 requestId_
    ) external onlyRole(VALIDATOR_ORACLE) {
        // this condition is necessary to avoid double check and unlocking an nft that was already changed
        // because of race condition among oracle request and fulfillment responses
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
     * @param collection_ the address of the nft collection
     * @param tokenId_ the nft token id
     * @return isInVault where the token is in vault or not
     */
    function isTokenInVault(address collection_, uint256 tokenId_) external view returns (bool isInVault) {
        address previousOwner = _holdings[collection_][tokenId_];
        return previousOwner != address(0);
    }

    /**
     * @notice allows to change tokens after a succesfull verification process
     * @param collection_ the address of the nft collection
     * @param tokenFrom_ the nft token id to change (from)
     * @param tokenTo_ the nft token id to change (to)
     */
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

    /**
     * @notice allows to withdraw a token after a succesfull verification process
     * @param collection_ the address of the nft collection
     * @param tokenId_ the nft token id to withdraw
     */
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
