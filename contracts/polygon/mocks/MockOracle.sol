// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../SyntheticProtocolRouter.sol";

contract MockOracle {

    address private router;

    constructor() {
    }

    function setRouter(address router_) public {
        router = router_;
    }

    function verifyNFT(address collection, uint256 tokenId) public {
        SyntheticProtocolRouter routerInstance = SyntheticProtocolRouter(router);
        routerInstance.verifyNFT(collection, tokenId);
    }

}
