// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTMock is ERC721 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    // solhint-disable-next-line
    constructor() ERC721("MyToken", "MTK") {}

    function safeMint(address to) public {
        _tokenIdCounter.increment();
        _safeMint(to, _tokenIdCounter.current());
    }
}
