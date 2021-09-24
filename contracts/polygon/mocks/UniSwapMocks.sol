// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract UniSwapFactoryMock {

    constructor() {
    }

    function createPair() public returns (address) {
        return address(0);
    }

}

contract UniSwapRouterMock {

    address private _uniswapFactory;

    constructor(address uniswapFactory_) {
        _uniswapFactory = uniswapFactory_;
    }

    function factory() public view returns (address) {
        return _uniswapFactory;
    }

}
