// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/ILTokenLite.sol";
import "./ERC20.sol";

contract LTokenLite is ILTokenLite, ERC20 {
    address private _pool;

    modifier _pool_() {
        require(msg.sender == _pool, "LToken: only pool");
        _;
    }

    // solhint-disable-next-line
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function pool() public view override returns (address) {
        return _pool;
    }

    function setPool(address newPool) public override {
        require(_pool == address(0) || _pool == msg.sender, "LToken.setPool: not allowed");
        _pool = newPool;
    }

    function mint(address account, uint256 amount) public override _pool_ {
        require(account != address(0), "LToken: mint to 0 address");

        _balances[account] += amount;
        _totalSupply += amount;

        emit Transfer(address(0), account, amount);
    }

    function burn(address account, uint256 amount) public override _pool_ {
        require(_balances[account] >= amount, "LToken: burn amount exceeds balance");

        _balances[account] -= amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }
}
