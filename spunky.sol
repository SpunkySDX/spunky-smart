// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SpunkySDX is Ownable {
    // Token details
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    // Token balances
    mapping(address => uint256) private _balances;
    mapping(address => mapping(uint8 => uint256)) private _allocationBalances;

    // Token allowances
    mapping(address => mapping(address => uint256)) private _allowances;

    // Vesting details
    uint256 private constant VESTING_PERIOD = 5;
    uint256 private constant RELEASE_INTERVAL = 30 days;
    mapping(address => uint256) private _vestingStart;
    mapping(address => uint256) private _vestingReleased;

    // Staking details
    uint256 private constant STAKING_APY = 5;
    mapping(address => uint256) private _stakingBalances;
    mapping(address => uint256) private _stakingRewards;

    // Token distribution details
    uint256 private WHITELIST_ALLOCATION = 0; 
    uint256 private PRESALE_ALLOCATION = 0; 
    uint256 private IEO_ALLOCATION = 0; 
    uint256 private AIRDROP_ALLOCATION = 0; 

    // Slippage tolerance
    uint256 private constant MAX_SLIPPAGE_TOLERANCE = 5;

    // Antibot features
    uint256 private constant MAX_HOLDING_PERCENTAGE = 5;
    uint256 private constant TRANSACTION_DELAY = 10 minutes;
    mapping(address => uint256) private _lastTransactionTime;

    //Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimRewards(address indexed user, uint256 reward);

   constructor() {
    name = "SpunkySDX";
    symbol = "SSDX";
    decimals = 18;
    totalSupply = 500e9 * 10**uint256(decimals);

    // Initially assign all tokens to the contract itself
    _balances[address(this)] = totalSupply;

    // Token distribution details based on total supply
    WHITELIST_ALLOCATION = totalSupply * 2 / 100; // 2% of total supply
    PRESALE_ALLOCATION = totalSupply * 20 / 100; // 20% of total supply
    IEO_ALLOCATION = totalSupply * 8 / 100; // 8% of total supply
    AIRDROP_ALLOCATION = totalSupply * 4 / 100; // 4% of total supply

    // Allocate tokens for the whitelist, presale, airdrop and IEO
    _allocationBalances[address(this)][1] = WHITELIST_ALLOCATION;
    _allocationBalances[address(this)][2] = PRESALE_ALLOCATION;
    _allocationBalances[address(this)][3] = IEO_ALLOCATION;
    _allocationBalances[address(this)][4] = AIRDROP_ALLOCATION;

    //Transfer Whitelist,presale and IEO allocation to the contract owner
    _transfer(address(this), owner(), WHITELIST_ALLOCATION + PRESALE_ALLOCATION + IEO_ALLOCATION);
      
    emit Transfer(address(0), address(this), totalSupply);
    emit Transfer(address(this), address(this), WHITELIST_ALLOCATION);
    emit Transfer(address(this), address(this), PRESALE_ALLOCATION);
    emit Transfer(address(this), address(this), IEO_ALLOCATION);
   }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allocationBalance(address account, uint8 allocation) public view returns (uint256) {
        require(allocation >= 1 && allocation <= 3, "Invalid allocation");
        return _allocationBalances[account][allocation];
    }

    function transfer(address recipient, uint256 amount) public checkTransactionDelay() checkMaxHolding(recipient, amount) returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public checkTransactionDelay() checkMaxHolding(spender, amount) returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public checkTransactionDelay() checkMaxHolding(recipient, amount) returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(amount <= currentAllowance, "ERC20: transfer amount exceeds allowance");

        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, currentAllowance - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public checkTransactionDelay() checkMaxHolding(spender, addedValue) returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public checkTransactionDelay() checkMaxHolding(spender, subtractedValue) returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(subtractedValue <= currentAllowance, "ERC20: decreased allowance below zero");

        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: transfer amount must be greater than zero");
        require(_balances[sender] >= amount, "ERC20: insufficient balance");

        uint256 slippageTolerance = amount * (MAX_SLIPPAGE_TOLERANCE / 100);
        uint256 minAmount = amount - slippageTolerance;
        uint256 maxAmount = amount + slippageTolerance;
        require(_balances[recipient] >= minAmount && _balances[recipient] <= maxAmount, "Amount exceeds recipient's balance");

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

    
    function redeemAirdrop(uint256 amount) external checkTransactionDelay() checkMaxHolding(msg.sender, amount) {
        require(amount > 0, "Invalid staking amount");
        require(_allocationBalances[address(this)][4] >= amount, "No airdrop balance available");

        _allocationBalances[address(this)][4] = _allocationBalances[address(this)][4] - amount;
        _transfer(address(this), msg.sender, amount);
        
    }

    function startVesting(address account) external onlyOwner {
        require(_vestingStart[account] == 0, "Vesting already started");
        _vestingStart[account] = block.timestamp;
    }

    function releaseVestedTokens() external onlyOwner {
        require(_vestingStart[msg.sender] > 0, "No vesting available");
        require(block.timestamp >= _vestingStart[msg.sender], "Vesting has not started yet");

        uint256 vestingPeriod = VESTING_PERIOD * 30 days;
        uint256 releaseInterval = RELEASE_INTERVAL * 30 days;

        uint256 totalVested = balanceOf(address(this)) - WHITELIST_ALLOCATION - PRESALE_ALLOCATION - IEO_ALLOCATION;
        uint256 tokensPerInterval = totalVested / (vestingPeriod * releaseInterval);

        uint256 intervalsPassed = (block.timestamp - _vestingStart[msg.sender]) / releaseInterval;
        uint256 tokensToRelease = tokensPerInterval * intervalsPassed;

        uint256 tokensReleased = _vestingReleased[msg.sender];
        uint256 newTokensReleased = tokensToRelease - tokensReleased;

        _vestingReleased[msg.sender] = tokensToRelease;
        _transfer(address(this), msg.sender, newTokensReleased);
    }

    function getVestingInfo(address account) external view returns (uint256, uint256, uint256) {
        require(_vestingStart[account] > 0, "No vesting available");

        uint256 vestingPeriod = VESTING_PERIOD * 30 days;
        uint256 releaseInterval = RELEASE_INTERVAL * 30 days;

        uint256 totalVested = balanceOf(address(this)) - WHITELIST_ALLOCATION - PRESALE_ALLOCATION - IEO_ALLOCATION;
        uint256 tokensPerInterval = totalVested / (vestingPeriod / releaseInterval);

        uint256 intervalsPassed = (block.timestamp - _vestingStart[account]) / (releaseInterval);
        uint256 tokensToRelease = tokensPerInterval * intervalsPassed;

        uint256 tokensReleased = _vestingReleased[account];
        uint256 newTokensReleased = tokensToRelease - tokensReleased;

        return (tokensToRelease, tokensReleased, newTokensReleased);
    }

    function calculateStakingReward(uint256 amount, uint256 duration) internal pure returns (uint256) {
        require(amount > 0, "Invalid staking amount");
        require(duration > 0, "Invalid staking duration");

        uint256 rewardPercentage = (STAKING_APY * duration) / 365 days;
        return (amount * rewardPercentage) / 100;
    }

    function updateStakingRewards(address staker, uint256 amount, uint256 duration) internal {
        require(duration > 0, "Invalid staking duration");
        require(staker != address(0), "Invalid staker address");
        require(amount > 0, "Invalid staking amount");

        uint256 rewards = calculateStakingReward(amount, duration);
        _stakingRewards[staker] = _stakingRewards[staker] + rewards;
    }

    function stake(uint256 amount, uint256 lockupDuration) external checkTransactionDelay() checkMaxHolding(msg.sender, amount) {
        require(amount > 0, "Invalid staking amount");
        require(lockupDuration > 0, "Invalid lockup duration");

        _transfer(msg.sender, address(this), amount);
        _stakingBalances[msg.sender] = _stakingBalances[msg.sender] + amount;

        updateStakingRewards(msg.sender, amount, lockupDuration);
        emit Stake(msg.sender, amount);
    }

    function unstake(uint256 amount) external checkTransactionDelay() {
        require(amount > 0, "Invalid unstaking amount");
        require(_stakingBalances[msg.sender] >= amount, "No staking balance available");

        _stakingBalances[msg.sender] = _stakingBalances[msg.sender] - amount;
        _transfer(address(this), msg.sender, amount);
        emit Unstake(msg.sender, amount);
    }

    function claimStakingRewards() external checkTransactionDelay() {
        require(_stakingRewards[msg.sender] > 0, "No staking rewards available");

        uint256 rewards = _stakingRewards[msg.sender];
        _stakingRewards[msg.sender] = 0;
        _transfer(address(this), msg.sender, rewards);
        emit ClaimRewards(msg.sender, rewards);
    }

    function getStakingRewards(address staker) external view returns (uint256) {
        return _stakingRewards[staker];
    }

    function getStakingBalance(address staker) external view returns (uint256) {
        return _stakingBalances[staker];
    }

    function renounceOwnership() public override onlyOwner {
        // Prevent renouncing ownership if there are staking rewards available
        require(_stakingRewards[msg.sender] == 0, "Staking rewards must be claimed before renouncing ownership");

        super.renounceOwnership();
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        super.transferOwnership(newOwner);
    }

    modifier checkTransactionDelay() {
        require(
            _lastTransactionTime[msg.sender] + TRANSACTION_DELAY <= block.timestamp,
            "Transaction cooldown period has not passed"
        );
        _lastTransactionTime[msg.sender] = block.timestamp;
        _;
    }

    modifier checkMaxHolding(address recipient, uint256 amount) {
        if (recipient != address(this) && recipient != owner()) {
            require(
                (_balances[recipient] + amount) <= (totalSupply * MAX_HOLDING_PERCENTAGE / 100),
                "Recipient's token holding exceeds the maximum allowed percentage"
            );
        }
        _;
    }
}
