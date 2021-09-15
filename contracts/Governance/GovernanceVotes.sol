// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract GovernanceVotes is ERC20Votes {
    constructor() ERC20Permit("Votes") ERC20("Votes", "Votes") {}
}
