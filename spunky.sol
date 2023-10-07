// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

 contract SpunkySDX is Ownable, ReentrancyGuard {
    // Token details
    string public name;
    string public symbol;
    uint8  public _decimals;
    uint256 public totalSupply;

    // Token balances
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address private _vestingContract;
    address private _stakingContract;


    // Token burn details
    uint256 public totalBurned;

    uint256 public constant SELL_TAX_PERCENTAGE = 50;

    // Antibot features
    uint256 private constant MAX_HOLDING_PERCENTAGE = 5;
    uint256 private constant TRANSACTION_DELAY = 2.5 minutes;
    mapping(address => uint256) private _lastTransactionTime;

    //Sell Tax Address
    address public constant SELL_TAX_ADDRESS = 0xF79948ACf0a91bD93513C76651a12291E44D2872;

    //Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner,  address indexed spender, uint256 value);
    event Burn(address indexed account, uint256 amount);
    event Withdrawn(uint256 amount);

    constructor() {
        name = "SpunkySDX";
        symbol = "SSDX";
        _decimals = 18;
        totalSupply = 500e9 * 10 ** uint256(_decimals);
        _balances[address(this)] = totalSupply;
        //Transfer Team and IEO allocation to the contract owner
        _transfer(address(this), owner(), totalSupply);

        emit Transfer(address(0), address(this), totalSupply);  
    }

    function getSymbol() public view returns (string memory) {
        return symbol;
    }

    function getName() public view returns (string memory) {
        return name;
    }

    function getSupply() public view returns (uint256) {
        return totalSupply;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    )
        public
        nonReentrant
        checkTransactionDelay
        checkMaxHolding(recipient, amount)
        returns (bool)
    {
        if (isSellTransaction(recipient)) {
            uint256 taxAmount = (amount * SELL_TAX_PERCENTAGE) / 10000;
            amount -= taxAmount;
            _transfer(msg.sender, SELL_TAX_ADDRESS, taxAmount);
        }
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public checkMaxHolding(spender, amount) returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public checkMaxHolding(recipient, amount) returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(
            amount <= currentAllowance,
            "ERC20: transfer amount exceeds allowance"
        );
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, currentAllowance - amount);
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public checkMaxHolding(spender, addedValue) returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public checkMaxHolding(spender, subtractedValue) returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(
            subtractedValue <= currentAllowance,
            "ERC20: decreased allowance below zero"
        );
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: transfer amount must be greater than zero");
        require(_balances[sender] >= amount, "ERC20: insufficient balance");

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function isSellTransaction(address recipient) internal view returns (bool) {
        return recipient == address(this);
    }

    function burn(uint256 amount) public onlyOwner {

        require(amount <= _balances[msg.sender], "Not enough tokens to burn");
        _balances[msg.sender] -= amount;
        totalSupply -= amount;
        totalBurned += amount;
        emit Transfer(msg.sender, address(0), amount);
        emit Burn(msg.sender, amount);
    }

    function setVestingContract(address vestingContract) external onlyOwner {
        _vestingContract = vestingContract;
    }

    function withdrawToken(
        address tokenAddress,
        uint256 tokenAmount
    ) external onlyOwner {

        IERC20 token = IERC20(tokenAddress);
        require(
            token.balanceOf(address(this)) >= tokenAmount,
            "Not enough tokens in the contract or owner cannot withdraw tokens in contract"
        );
        require(
            tokenAddress != address(this),
            "Owner cannot withdraw SSDX tokens in contract"
        );
        token.transfer(owner(), tokenAmount);
    }

    function withdraw() external onlyOwner {
       uint256 amount = address(this).balance;
       payable(owner()).transfer(amount);

       emit Withdrawn(amount);
    }

    function renounceOwnership() public override onlyOwner {
        // Prevent renouncing ownership if there are staking rewards available
        super.renounceOwnership();
    }

   function transferOwnership(address newOwner) public override onlyOwner {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    // Transfer the balance of the current owner to the new owner
    uint256 balanceOfCurrentOwner = _balances[owner()];
    _balances[owner()] = 0;
    _balances[newOwner] += balanceOfCurrentOwner;
    emit Transfer(owner(), newOwner, balanceOfCurrentOwner);
    // Transfer the ownership
    super.transferOwnership(newOwner);
   }  
   

     function setStakingContract(address stakingContract) public onlyOwner {
    _stakingContract = stakingContract;
    }
   

    modifier checkTransactionDelay() {
        require(
            _lastTransactionTime[msg.sender] + TRANSACTION_DELAY <=
                block.timestamp,
            "Transacation cooldown period has not passed"
        );
        _lastTransactionTime[msg.sender] = block.timestamp;
        _;
    }

    modifier checkMaxHolding(address recipient, uint256 amount) {
        if (recipient != address(this) && recipient != owner() && recipient != _vestingContract && recipient != _stakingContract) {
            require(
                (_balances[recipient] + amount) <=
                    ((totalSupply * MAX_HOLDING_PERCENTAGE) / 100),
                "Recipient's token holding exceeds the maximum allowed percentage"
            );
        }
        _;
    }
}
