// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces.sol";
import "./Governance/IGovernanceData.sol";

contract NFTFractions is IERC20, Pausable, Ownable {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint256 private _decimals;

    // address of the vault
    address private vaultAddress;

    //this is used to calculate price based on a divisor
    uint256 private _priceInWei;

    IGovernanceData private governanceData;

    uint256 private _raisedFees;
    uint256 private _raisedFunds;

    // the timestamp of the deployment block
    uint256 private _deployTimestamp;

    // maximum supply to be sold
    uint256 supplyToBeIssued;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    // will use this modifier in a function to pause token when auction ends
    modifier onlyVault() {
        require(msg.sender == vaultAddress, "onlyVault: caller is not the vault");
        _;
    }

    /**
     * @dev Instantiate the contract
     * @param beneficiary the owner of the tokens
     * @param vaultAddress_ the vault's address
     * @param name_ ERC20 token name
     * @param symbol_ ERC20 token symbol
     * @param decimals_ ERC20 token decimals
     * @param totalSupply_ total Supply
     * @param _supplyToBeIssued how much tokens to be sold
     * @param initialPrice initial sell price
     * @param governanceAddress the address of the Governance Data contract
     * @param swapAddress uniswap or clone address
     */
    constructor(
        address beneficiary,
        address vaultAddress_,
        string memory name_,
        string memory symbol_,
        uint256 decimals_,
        uint256 totalSupply_,
        uint256 _supplyToBeIssued,
        uint256 initialPrice,
        address governanceAddress,
        address swapAddress
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _deployTimestamp = block.timestamp;

        uint256 initialMintAmount = totalSupply_ * 10**decimals_;
        uint256 sellAmount = _supplyToBeIssued * 10**decimals_;

        require(sellAmount <= initialMintAmount / 2, "");

        // Give all tokens to beneficiary and transfer ownership
        _mint(address(beneficiary), initialMintAmount);
        _transfer(address(beneficiary), address(this), sellAmount);

        vaultAddress = address(vaultAddress_);

        supplyToBeIssued = _supplyToBeIssued;
        _priceInWei = initialPrice;

        governanceData = IGovernanceData(governanceAddress);

        transferOwnership(vaultAddress_);

        // Initialize swap and create pair
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(swapAddress);
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
            address(this),
            _uniswapV2Router.WETH()
        );
    }

    /**
     * @dev buy tokens
     */
    function buy() public payable {
        uint256 amountTobuy = msg.value / _priceInWei;
        uint256 contractBalance = balanceOf(address(this));
        require(amountTobuy > 0, "You need to send some ether");
        require(amountTobuy <= contractBalance, "Not enough tokens to be sold");
        _transfer(address(this), _msgSender(), amountTobuy);
        uint256 _fee = governanceData.tradingFee();
        uint256 fee = (msg.value / 100) * _fee;
        uint256 raisedFunds_ = msg.value - fee;

        _raisedFunds += raisedFunds_;

        if (balanceOf(address(this)) == 0) {
            addLiquidity();
        }
    }

    /**
     * @dev withdraw fees from contract. only owner
     * @param _amount (in wei)
     */
    function withdrawFees(uint256 _amount, address beneficiary) public onlyOwner {
        require(_amount >= _raisedFees, "Not enough fees!");
        payable(_msgSender()).transfer(_amount);
    }

    //to receive ETH from uniswapV2Router when swaping
    receive() external payable {}

    //TODO: adjust uniswap price formula

    function addLiquidity() private {
        require(balanceOf(address(this)) == 0, "All tokens must be sold before adding liquidity");

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), leftSupply());

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: _raisedFunds}(
            address(this),
            leftSupply(),
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    /**
     * @dev Returns the deploy timestamp
     */
    function deployTimestamp() public view returns (uint256) {
        return _deployTimestamp;
    }

    /**
     * @dev Returns price in wei of each token
     */
    function priceInWei() public view returns (uint256) {
        return _priceInWei;
    }

    function leftSupply() public view returns (uint256) {
        return _totalSupply - supplyToBeIssued;
    }

    function remainingSupply() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function raisedFunds() public view returns (uint256) {
        //uint soldTokens = supplyToBeIssued - balanceOf(address(this));
        //uint raisedFunds_ = soldTokens * _priceInWei;
        //return raisedFunds_;
        return _raisedFunds;
    }

    function UniswapInitialPrice() public view returns (uint256) {
        uint256 _remainingSupply = remainingSupply();
        uint256 _UniSwapInitialPrice = _remainingSupply / (supplyToBeIssued * _priceInWei);
        return _UniSwapInitialPrice;
    }

    /**
     * @dev PabMac
     * @notice This contract has been paused
     */
    function pause() public onlyVault {
        _pause();
    }

    /**
     * @dev PabMac
     * @notice This contract has been unpaused
     */
    function unpause() public onlyVault {
        _unpause();
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint256) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}
