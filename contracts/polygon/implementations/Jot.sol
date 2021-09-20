// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../Interfaces.sol";

contract Jot is ERC20, AccessControl, Initializable {
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

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(swapAddress);
        uniswapV2Router = _uniswapV2Router;

        // uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
        //     address(this),
        //     fundingTokenAddress
        // );
    }

    function mint(address account, uint256 amount) public onlyRole(MINTER) {
        _mint(account, amount);
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
