// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../governance/ProtocolParameters.sol";
import "../implementations/Structs.sol";
import "./ProtocolConstants.sol";
import "hardhat/console.sol";

/**
 * @title helpers for synthetic token operations
 * @author priviprotocol
 */
library SyntheticTokenLibrary {
    /**
     * @dev helper for increase selling supply
     * @param amount the quantity of supply to increase
     */
    function increaseSellingSupply(TokenData storage token, uint256 amount) external {
        require(amount > 0, "Amount can't be zero!");
        require(!isLocked(token.state, token.ownerSupply), "Token is locked!");
        require(token.ownerSupply >= amount, "You do not have enough tokens left");

        token.ownerSupply -= amount;
        token.sellingSupply += amount;
    }

    /**
     * @dev helper for decrease selling supply
     * @param amount the quantity of supply to decrease
     */
    function decreaseSellingSupply(TokenData storage token, uint256 amount) external {
        require(amount > 0, "Amount can't be zero!");
        require(!isLocked(token.state, token.ownerSupply), "Token is locked!");

        require(token.sellingSupply >= amount, "You do not have enough selling supply left");

        token.ownerSupply += amount;
        token.sellingSupply -= amount;
    }

    /**
     * @dev helper for update price fraction
     * @param newFractionPrice the quantity of supply to increase
     */
    function updatePriceFraction(TokenData storage token, uint256 newFractionPrice) external {
        require(newFractionPrice > 0, "Fraction price must be greater than zero");
        require(!isLocked(token.state, token.ownerSupply), "Token is locked!");

        token.fractionPrices = newFractionPrice;
    }

    /**
     * @dev helper for buy jot tokens
     * @param amount the quantity of jots to buy
     */
    function buyJotTokens(TokenData storage token, uint256 amount) external returns (uint256 amountToPay) {
        require(amount > 0, "Amount can't be zero!");
        require(!isLocked(token.state, token.ownerSupply), "Token is locked!");

        // calculate amount left
        uint256 amountLeft = token.sellingSupply - token.soldSupply;

        require(amountLeft > 0, "No available tokens for sale");
        require(amount <= amountLeft, "Not enough available tokens");

        amountToPay = (amount * token.fractionPrices) / 10**18;

        // Can't sell zero tokens
        require(amountToPay > 0, "No tokens left!");

        //Increase sold supply (amount in token) and liquidity sold (amount in ether)
        token.soldSupply += amount;
        token.liquiditySold += amountToPay;
    }

    /**
     * @dev helper for deposit jot tokens
     * @param amount the quantity of jots to deposit
     */
    function depositJotTokens(TokenData storage token, uint256 amount) external {
        require(amount > 0, "Amount can't be zero!");

        // save gas through memory
        uint256 ownerSupply = token.ownerSupply;

        require(!isLocked(token.state, ownerSupply), "Token is locked!");

        uint256 result = ownerSupply + amount;
        require(result <= ProtocolConstants.JOT_SUPPLY, "You can't deposit more than the Jot Supply limit");

        token.ownerSupply += amount;
    }

    function isLocked(State state, uint256 ownerSupply) internal pure returns (bool) {
        return state != State.VERIFIED || ownerSupply == 0;
    }
}
