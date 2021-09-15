// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFT.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ERC721TokenFactory {

	// Number of deployments
	using Counters for Counters.Counter;
	Counters.Counter public _tokenIdCounter;

	// Addresses of deployed contracts
	mapping (uint => address) public deployData;

	constructor() {}

	/**
	* @dev Deploy ERC20 token
	 * @param vaultAddress the vault's address
	 * @param name_ ERC20 token name
	 * @param symbol_ ERC20 token symbol
	 * @param governanceAddress the address of the Governance Data contract
	 */
	function deployERC721(
		address vaultAddress,
		string memory name_,
		string memory symbol_,
		address governanceAddress
		) public returns (address) {
			ERC721 erc721 = new ERC721(
				name_,
				symbol_,
				vaultAddress,
				governanceAddress
		);

		deployData[_tokenIdCounter.current()] = address(erc721);
		_tokenIdCounter.increment();
		return address(erc721);
	}
}

