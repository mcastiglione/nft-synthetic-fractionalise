// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../extensions/IERC20ManagedAccounts.sol";
import "../Interfaces.sol";

contract Jot is ERC20, IERC20ManagedAccounts, ERC20Burnable, AccessControl, Initializable {
    bytes32 public constant ROUTER = keccak256("ROUTER");
    bytes32 public constant MINTER = keccak256("MINTER");

    // proxied values for the erc20 attributes
    string private _proxiedName;
    string private _proxiedSymbol;

    /**
     * @notice *swap address
     */
    IUniswapV2Router02 public uniswapV2Router;

    /**
     * @notice pair address
     */
    address public uniswapV2Pair;

    mapping(address => address) private _managers;

    // solhint-disable-next-line
    constructor() ERC20("Privi Jot Token Implementation", "pJOTI") {}

    function initialize(
        string calldata _name,
        string calldata _symbol,
        address swapAddress,
        address fundingTokenAddress
    ) external initializer {
        _proxiedName = _name;
        _proxiedSymbol = _symbol;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ROUTER, msg.sender);

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(swapAddress);
        uniswapV2Router = _uniswapV2Router;

        IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), fundingTokenAddress);

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).getPair(
            address(this),
            fundingTokenAddress
        );
    }

    function mint(address account, uint256 amount) public onlyRole(MINTER) {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyRole(MINTER) {
        _burn(account, amount);
    }

    /**
     * @dev allows to send funds from a managed account (infinite allowance)
     */
    function transferFromManaged(
        address sender,
        address recipient,
        uint256 amount
    ) external virtual override {
        require(_managers[sender] == msg.sender, "The caller is not the manager of this account");
        _transfer(sender, recipient, amount);
    }

    function setManager(address manager, address account) external onlyRole(ROUTER) {
        _managers[account] = manager;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _proxiedName;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _proxiedSymbol;
    }
}
