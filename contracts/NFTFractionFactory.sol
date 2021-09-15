// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFTFractions.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTFractionFactory {
    // Number of deployments
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIdCounter;

    // Addresses of deployed contracts
    mapping(uint256 => address) public deployData;

    constructor() {}

    /**
     * @dev Deploy NFTFractions token
     * @param beneficiary the owner of the token
     * @param vaultAddress the vault's address
     * @param name_ ERC20 token name
     * @param symbol_ ERC20 token symbol
     * @param decimals_, ERC20 token decimals
     * @param totalSupply_, total Supply
     * @param _supplyToBeIssued how much tokens to be sold
     * @param initialPrice initial sell price
     * @param governanceAddress the address of the Governance Data contract
     * @param swapAddress uniswap or clones address
     */
    function deployNFTFractions(
        address beneficiary,
        address vaultAddress,
        string memory name_,
        string memory symbol_,
        uint256 decimals_,
        uint256 totalSupply_,
        uint256 _supplyToBeIssued,
        uint256 initialPrice,
        address governanceAddress,
        address swapAddress
    ) public returns (address) {
        NFTFractions nftfractions = new NFTFractions(
            beneficiary,
            vaultAddress,
            name_,
            symbol_,
            decimals_,
            totalSupply_,
            _supplyToBeIssued,
            initialPrice,
            governanceAddress,
            swapAddress
        );

        deployData[_tokenIdCounter.current()] = address(nftfractions);
        _tokenIdCounter.increment();
        return address(nftfractions);
    }
}
