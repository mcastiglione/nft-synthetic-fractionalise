// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract AuctionsManagerUpgradeMock is UUPSUpgradeable {
    function isRecoverable(uint256) public pure returns (bool) {
        return true;
    }

    // solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal override {}
}
