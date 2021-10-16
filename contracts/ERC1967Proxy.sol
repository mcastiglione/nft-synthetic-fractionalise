// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ERC1967ProxyHHDeployCompatible is ERC1967Proxy {
    constructor(
        address _logic,
        address,
        bytes memory _data
    ) payable ERC1967Proxy(_logic, _data) {} // solhint-disable-line
}
