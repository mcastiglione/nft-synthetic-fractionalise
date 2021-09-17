// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces.sol";

contract Jot is ERC20{

    /**
     * @notice The current owner of the contract.
     */
    address public owner;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
    /**
     * @notice *swap address
     */
    IUniswapV2Router02 public immutable uniswapV2Router;

    /**
    * @notice pair address
     */
    address public uniswapV2Pair;

    constructor(address _owner, address swapAddress) ERC20("Privi Jot", "JOT") {
        owner = _owner;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(swapAddress);
		uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
			.createPair(address(this), _uniswapV2Router.WETH());
    }

    function safeMint(address account, uint256 amount) public onlyOwner {
      _mint(account, amount);
    }
}
