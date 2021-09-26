// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BTokenMock is ERC20 {
    // solhint-disable-next-line
    constructor() ERC20("Privi B Token Mock", "pBTM") {
        _mint(msg.sender, 10000000000 * 10**decimals());
    }
}
