// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../../polygon/Interfaces.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract LTokenLite is ILTokenLite, Initializable, AccessControl, ERC20 {
    bytes32 public constant ROUTER = keccak256("ROUTER");

    // proxied values for the erc20 attributes
    string private _proxiedName;
    string private _proxiedSymbol;
    address private _pool;

    modifier _pool_() {
        require(msg.sender == _pool, "LToken: only pool");
        _;
    }

    // solhint-disable-next-line
    constructor() ERC20("Future Liquidity Token", "FLT") {}

    function initialize(string memory name_, string memory symbol_) external initializer {
        _proxiedName = name_;
        _proxiedSymbol = symbol_;

        _setupRole(ROUTER, msg.sender);
    }

    function name() public view override returns (string memory) {
        return _proxiedName;
    }

    function symbol() public view override returns (string memory) {
        return _proxiedSymbol;
    }

    function pool() public view override returns (address) {
        return _pool;
    }

    function setPool(address newPool) public override onlyRole(ROUTER) {
        require(_pool == address(0), "LToken.setPool: not allowed");
        _pool = newPool;
    }

    function mint(address account, uint256 amount) public override _pool_ {
        require(account != address(0), "LToken: mint to 0 address");
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public override _pool_ {
        _burn(account, amount);
    }
}
