// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";
//import "https://github.com/priviprotocol/privi-financial-derivatives/blob/dev/contracts/pool/EverlastingOption.sol";

contract Vault is IERC721Receiver {

  using Counters for Counters.Counter;

	Counters.Counter private _bidCounter;

  /* ****** */
  /* EVENTS */
  /* ****** */

  event NFTReceived(
    address operator,
    address from,
    uint256 tokenId,
    bytes data
  );

  /* ******* */
  /* STRUCTS */
  /* ******* */

  // State variables
  /// @notice The current owner of the vault.
  address public owner;

  // NFT address => NFT ID => Original Owner
  mapping (address => mapping (uint256 => address) ) public tokenData;
  
  /**
  * @dev Throws if called by any account other than the owner.
  */
  modifier onlyOwner {
    require(msg.sender == owner, "Ownable: caller is not the owner");
    _;
  }

  /**
  * @param _owner the owner of the Vault
  */
  constructor(address _owner) {
    owner = _owner;
  }

  /**
   * @dev See {IERC721Receiver-onERC721Received}.
   */
  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes memory data
  ) public virtual override returns (bytes4) {
    
    tokenData[operator][tokenId] = msg.sender;

    emit NFTReceived(operator, from, tokenId, data);

    return this.onERC721Received.selector;
  }

  function isTokenInVault(address operator, uint256 tokenId) public view returns (bool) {
    address previousOwner = tokenData[operator][tokenId];
    if (previousOwner != address(0)) {
      return true;
    } else {
      return false;
    }
  }

}

