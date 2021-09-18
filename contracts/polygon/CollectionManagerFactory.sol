// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./SyntheticCollectionManager.sol";

contract CollectionManagerFactory {

    constructor() {

    }

    function deploy(
        address originalCollectionAddress_, 
        string memory name_, 
        string memory symbol_
    ) public returns (address) {
        SyntheticCollectionManager manager = new SyntheticCollectionManager(
            originalCollectionAddress_, 
            name_, symbol_
        );
        return address(manager);

    }
}