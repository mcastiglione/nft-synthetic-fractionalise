// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

/**
 * @dev allows to send funds from a managed account (infinite allowance)
 */
interface IERC20ManagedAccounts {
    function transferFromManaged(
        address sender,
        address recipient,
        uint256 amount
    ) external;
}
