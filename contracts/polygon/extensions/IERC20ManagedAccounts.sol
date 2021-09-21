// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IERC20ManagedAccounts {
    function transferFromManaged(
        address sender,
        address recipient,
        uint256 amount
    ) external;
}
