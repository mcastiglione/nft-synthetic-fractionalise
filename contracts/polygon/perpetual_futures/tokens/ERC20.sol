// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IERC20.sol";

contract ERC20 is IERC20 {
    uint8 internal constant DECIMALS = 18;

    string internal _name;
    string internal _symbol;
    uint256 internal _totalSupply;

    mapping(address => uint256) internal _balances;

    mapping(address => mapping(address => uint256)) internal _allowances;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        require(spender != address(0), "ERC20.approve: to 0 address");
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(to != address(0), "ERC20.transfer: to 0 address");
        require(_balances[msg.sender] >= amount, "ERC20.transfer: amount exceeds balance");
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(to != address(0), "ERC20.transferFrom: to 0 address");
        require(_balances[from] >= amount, "ERC20.transferFrom: amount exceeds balance");

        if (msg.sender != from && _allowances[from][msg.sender] != type(uint256).max) {
            require(_allowances[from][msg.sender] >= amount, "ERC20.transferFrom: amount exceeds allowance");
            uint256 newAllowance = _allowances[from][msg.sender] - amount;
            _approve(from, msg.sender, newAllowance);
        }

        _transfer(from, to, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }
}
