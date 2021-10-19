// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../implementations/Structs.sol";

/**
 * @title helpers for synthetic token operations
 * @author priviprotocol
 */
library SyntheticTokenLibrary {
    function increaseSellingSupply(TokenData storage token, uint256 amount) external {
        require(token.ownerSupply >= amount, "You do not have enough tokens left");
        token.ownerSupply -= amount;
        token.sellingSupply += amount / 2;
        token.liquiditySupply += amount / 2;
    }
}
