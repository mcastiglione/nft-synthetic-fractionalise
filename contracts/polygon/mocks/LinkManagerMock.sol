// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

contract LinkManagerMock {
    address private router;

    // solhint-disable-next-line
    constructor() {}

    // solhint-disable-next-line
    function swapToLink() external {}

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // solhint-disable-next-line
    receive() external payable {}
}
