// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SpunkySDX is Ownable, ReentrancyGuard {
    // Token details
    string  public name;
    string  public symbol;
    uint8   public _decimals;
    uint256 public totalSupply;

    IERC20 public usdtToken;

    // Token balances
    mapping(address => uint256) private _balances;
    mapping(address => mapping(uint8 => uint256)) private _allocationBalances;

    // Define the staking plans
    enum StakingPlan { ThirtyDays, NinetyDays, OneEightyDays, ThreeSixtyDays }
 
    // Define the returns for each plan
    mapping(StakingPlan => uint256) private _stakingPlanReturns;
   
    // Token allowances
    mapping(address => mapping(address => uint256)) private _allowances;

    // Staking details
    mapping(address => uint256) private _stakingBalances;
    mapping(address => uint256) private _stakingRewards;
    mapping(StakingPlan => uint256) private _stakingPlanDurations;
    mapping(address => uint256) private _stakingStartTimes;
    mapping(address => StakingPlan) private _stakingPlans;

    // Vesting details
    mapping(address => VestingDetail) private _vestingDetails;

    struct VestingDetail {
        uint256 amount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 releasedAmount;
    }

    // Fixed price for buying tokens during the presale (in wei per token)
    uint256 public presalePrice = 0.000001;
   
    // State to determine if the contract is in presale or launch state
    bool public isPresale = true;

    // Token distribution details
    uint256 private WHITELIST_ALLOCATION = 0; 
    uint256 private PRESALE_ALLOCATION = 0; 
    uint256 private IEO_ALLOCATION = 0;  
    uint256 private AIRDROP_ALLOCATION = 0;  
    uint256 private TEAM_ALLOCATION = 0;  
    uint256 private STAKING_ALLOCATION = 0;
    
    //Staking rewards
    uint256 public totalRewardsGiven = 0;

    // Token burn details
    uint256 public totalBurned;
    uint256 public MAX_BURN = 0; 

    // Slippage tolerance, Airdrop
    uint256 public constant SELL_TAX_PERCENTAGE = 5;
    mapping(address => bool) private _airdropRedeemed;
    mapping(address => bool) private _canRedeem;

    // Antibot features
    uint256 private constant MAX_HOLDING_PERCENTAGE = 5;
    uint256 private constant TRANSACTION_DELAY = 2.5 minutes;
    mapping(address => uint256) private _lastTransactionTime;

    //Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimRewards(address indexed user, uint256 reward);
    event VestingScheduleAdded(address indexed account, uint256 amount, uint256 startTime, uint256 cliff, uint256 endTime);
    event Burn(address indexed account, uint256 amount);
    event TokensReleased(address indexed account, uint256 amount);

   constructor() {
        name = "SpunkySDX";
        symbol = "SSDX";
        _decimals = 18;
        totalSupply = 500e9 * 10**uint256(_decimals);

        // Initially assign all tokens to the contract itself
        _balances[address(this)] = totalSupply;

        usdtToken = IERC20(0x7169D38820dfd117C3FA1f22a697dBA58d90BA06); // USDT contract address on Ethereum

        // Token distribution details based on total supply
        WHITELIST_ALLOCATION = totalSupply * 2 / 100; // 2% of total supply
        PRESALE_ALLOCATION = totalSupply * 20 / 100; // 20% of total supply
        IEO_ALLOCATION = totalSupply * 8 / 100; // 8% of total supply
        AIRDROP_ALLOCATION = totalSupply * 4 / 100; // 4% of total supply
        TEAM_ALLOCATION = totalSupply * 6 / 100; // 6% of total supply
        STAKING_ALLOCATION = totalSupply * 20 / 100; // 20% of total supply
        MAX_BURN = totalSupply * 10 / 100;  // 10% of total supply

        // Define the returns for each staking plan
        _stakingPlanReturns[StakingPlan.ThirtyDays] = 5;
        _stakingPlanReturns[StakingPlan.NinetyDays] = 10;
        _stakingPlanReturns[StakingPlan.OneEightyDays] = 30;
        _stakingPlanReturns[StakingPlan.ThreeSixtyDays] = 50;

        // Initialize the durations for each staking plan
        _stakingPlanDurations[StakingPlan.ThirtyDays] = 30;
        _stakingPlanDurations[StakingPlan.NinetyDays] = 90;
        _stakingPlanDurations[StakingPlan.OneEightyDays] = 180;
        _stakingPlanDurations[StakingPlan.ThreeSixtyDays] = 360;
        
        // Allocate tokens for the whitelist, presale, airdrop and IEO
        _allocationBalances[address(this)][1] = WHITELIST_ALLOCATION;
        _allocationBalances[address(this)][2] = PRESALE_ALLOCATION;
        _allocationBalances[address(this)][3] = IEO_ALLOCATION;
        _allocationBalances[address(this)][4] = AIRDROP_ALLOCATION;
        _allocationBalances[address(this)][5] = TEAM_ALLOCATION;
        _allocationBalances[address(this)][6] = STAKING_ALLOCATION;

        //Transfer Team and IEO allocation to the contract owner
        _transfer(address(this), owner(), IEO_ALLOCATION + TEAM_ALLOCATION);
        
        emit Transfer(address(0), address(this), totalSupply);
        emit Transfer(address(this), address(this), WHITELIST_ALLOCATION);
        emit Transfer(address(this), address(this), PRESALE_ALLOCATION);
        emit Transfer(address(this), address(this), IEO_ALLOCATION);
        emit Transfer(address(this), address(this), AIRDROP_ALLOCATION);
        emit Transfer(address(this), address(this), TEAM_ALLOCATION);
        emit Transfer(address(this), address(this), STAKING_ALLOCATION);
    }

    function getSymbol() public view returns (string memory) {
      return symbol;
    }

    function getName() public view returns (string memory) {
       return name;
    }

    function getTotalSupply() public view returns (uint256) {
        return totalSupply;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }


    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allocationBalance(address account, uint8 allocation) public view returns (uint256) {
        require(allocation >= 1 && allocation <= 6, "Invalid allocation");
        return _allocationBalances[account][allocation];
    }

    function transfer(address recipient, uint256 amount) public nonReentrant checkTransactionDelay() checkMaxHolding(recipient, amount) returns (bool) {
        if (isSellTransaction(recipient)) {
            uint256 taxAmount = (amount * SELL_TAX_PERCENTAGE) / 100;
            amount -= taxAmount;
            _transfer(msg.sender, owner(), taxAmount); 
        }
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public checkMaxHolding(spender, amount) returns (bool) {
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

    function increaseAllowance(address spender, uint256 addedValue) public checkMaxHolding(spender, addedValue) returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public checkMaxHolding(spender, subtractedValue) returns (bool) {
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

    function setCanRedeemAirdrop(address[] calldata airdropRecipients, bool canRedeem) external nonReentrant onlyOwner() {
      for (uint256 i = 0; i < airdropRecipients.length; i++) {
         _canRedeem[airdropRecipients[i]] = canRedeem;
       }
    }
    
    function redeemAirdrop(uint256 amount) nonReentrant external checkTransactionDelay() checkMaxHolding(msg.sender, amount) checkIsAirDropReedemable() {
        require(!_airdropRedeemed[msg.sender], "Airdrop already redeemed");
        require(amount > 0 && amount<= 1000, "Invalid amount");
        require(_allocationBalances[address(this)][4] >= amount, "No airdrop balance available");

        _airdropRedeemed[msg.sender] = true; 
        _allocationBalances[address(this)][4] -= amount;
        _transfer(address(this), msg.sender, amount);
    }


    function addVestingSchedule(address account, uint256 amount, uint256 cliffDuration, uint256 vestingDuration) nonReentrant checkTransactionDelay() public {
        require(account != address(0), "Invalid account");
        require(amount > 0, "Invalid amount");
        require(cliffDuration < vestingDuration, "Cliff duration must be less than vesting duration");
        require(_balances[owner()] >= amount, "Owner does not have enough balance"); 

        _vestingDetails[account] = VestingDetail({
            amount: amount,
            startTime: block.timestamp,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            releasedAmount: 0
        });

        _transfer(owner(), account, amount);

        emit VestingScheduleAdded(account, amount, block.timestamp, cliffDuration, vestingDuration);
   }

   function releaseVestedTokens(address account) nonReentrant external onlyOwner() {
    require(account != address(0), "Invalid account");
    VestingDetail storage vesting = _vestingDetails[account];
    require(vesting.amount > 0, "No vesting available");
    
    uint256 elapsedTime = block.timestamp - vesting.startTime;
    require(elapsedTime >= vesting.cliffDuration, "Cliff period has not ended");

    uint256 releaseableAmount = (elapsedTime * vesting.amount) / vesting.vestingDuration;
    uint256 unreleasedAmount = releaseableAmount - vesting.releasedAmount;

    require(unreleasedAmount > 0, "No tokens to release");

    vesting.releasedAmount += unreleasedAmount;
    _transfer(address(this), account, unreleasedAmount);

    emit TokensReleased(account, unreleasedAmount);
   }


    function calculateStakingReward(uint256 amount, StakingPlan plan) internal view returns (uint256) {
        require(amount > 0, "Invalid staking amount");

        uint256 rewardPercentage = _stakingPlanReturns[plan];
        return (amount * rewardPercentage) / 1000;
    }

   function stake(uint256 amount, StakingPlan plan) nonReentrant external checkTransactionDelay() checkMaxHolding(msg.sender, amount) {
        require(amount > 0, "Invalid staking amount");
        require(_stakingBalances[msg.sender] == 0, "This address already has an active stake");

        uint256 reward = calculateStakingReward(amount, plan);
        require(_allocationBalances[address(this)][6] >= reward, "Staking rewards exhausted");

        _transfer(msg.sender, address(this), amount);
        _stakingBalances[msg.sender] = amount;

        _stakingStartTimes[msg.sender] = block.timestamp;
        _stakingPlans[msg.sender] = plan;
        _stakingRewards[msg.sender] = reward;

        _allocationBalances[address(this)][6] -= reward; // Decrement the staking allocation balance

        emit Stake(msg.sender, amount);
   }

   function unstake(uint256 amount) nonReentrant external checkTransactionDelay() {
    require(amount > 0, "Invalid unstaking amount");
    require(_stakingBalances[msg.sender] >= amount, "No staking balance available");

    // If unstaking before the plan duration, all rewards are lost
    if (block.timestamp < _stakingStartTimes[msg.sender] + _stakingPlanDurations[_stakingPlans[msg.sender]] * 1 days) {
        _stakingRewards[msg.sender] = 0;
    }

    _stakingBalances[msg.sender] -= amount;
    _transfer(address(this), msg.sender, amount);
    emit Unstake(msg.sender, amount);
   }


   function claimStakingRewards() nonReentrant public checkTransactionDelay() {
    require(block.timestamp >= _stakingStartTimes[msg.sender] + _stakingPlanDurations[_stakingPlans[msg.sender]] * 1 days, "Staking period has not ended");
    require(_stakingBalances[msg.sender] > 0, "No staking balance available");

    uint256 rewards = _stakingRewards[msg.sender];
    uint256 totalAmount = _stakingBalances[msg.sender] + rewards;

    _stakingRewards[msg.sender] = 0;
    _stakingBalances[msg.sender] = 0;

    _transfer(address(this), msg.sender, totalAmount);
    emit ClaimRewards(msg.sender, totalAmount);
   }


    function isSellTransaction(address recipient) internal view returns (bool) {
        return recipient == address(this);
    }

   function burn(uint256 amount) public  onlyOwner() {
        require(totalBurned + amount <= MAX_BURN, "Total burned exceeds max burn amount");
        require(amount <= _balances[msg.sender], "Not enough tokens to burn");

        _balances[msg.sender] -= amount;
        totalSupply -= amount;
        totalBurned += amount;

        emit Transfer(msg.sender, address(0), amount);
        emit Burn(msg.sender, amount);
    }

    function getStakingRewards(address staker) external view returns (uint256) {
        return _stakingRewards[staker];
    }

    function getStakingBalance(address staker) external view returns (uint256) {
        return _stakingBalances[staker];
    }

    function buyTokens(uint256 usdtAmount) public checkMaxHolding(msg.sender, usdtAmount) {
        require(isPresale, "Presale has ended");
        require(msg.sender != owner(), "Owner cannot participate in presale");
        require(usdtToken.balanceOf(msg.sender) >= usdtAmount, "Insufficient USDT balance");

        uint256 tokensToBuy = usdtAmount * presalePrice;

        // Check if the presale allocation is sufficient
        require(_allocationBalances[address(this)][2] >= tokensToBuy, "Not enough presale tokens available");

        // Calculate the immediate release and vested amounts
        uint256 immediateRelease = tokensToBuy / 4; // 25%
        uint256 vestedAmount = (tokensToBuy * 3) / 4; // 75%

        // Update the presale allocation
        _allocationBalances[address(this)][2] -= tokensToBuy;

        // Transfer the immediate release portion
        _transfer(address(this), msg.sender, immediateRelease);

        // Set up the vesting schedule for the vested amount, over 5 months
        uint256 cliffDuration = 0; // No cliff for presale
        uint256 vestingDuration = 30 days * 5; // 5 months
        addVestingSchedule(msg.sender, vestedAmount, cliffDuration, vestingDuration);

        // Transfer USDT from the buyer to the contract
        usdtToken.transferFrom(msg.sender, address(this), usdtAmount);
    }

    function withdrawToken(address tokenAddress, uint256 tokenAmount) external onlyOwner {
     require(isPresale == false, "Presale has ended");

     IERC20 token = IERC20(tokenAddress);
     require(token.balanceOf(address(this)) >= tokenAmount, "Not enough tokens in the contract");
     token.transfer(owner(), tokenAmount);
    }


    function endPresale() external onlyOwner {
        isPresale = false;
    }  

    function renounceOwnership() public override onlyOwner {
        // Prevent renouncing ownership if there are staking rewards available
        require(_stakingRewards[msg.sender] == 0, "Staking rewards must be claimed before renouncing ownership");

        super.renounceOwnership();
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        super.transferOwnership(newOwner);
    }

    function getStakingAllocation() external view returns (uint256) {
     return _allocationBalances[address(this)][6];
    }

    function getPresaleState() external view returns (bool) {
     return isPresale;
    }

    function getPresalePrice() external view returns (uint256) {
     return presalePrice;
    }

    function getPresaleAllocation() external view returns (uint256) {
     return _allocationBalances[address(this)][2];
    }

    function getAirdropAllocation() external view returns (uint256) {
     return _allocationBalances[address(this)][4];
    }

    function getTotalBurned() external view returns (uint256) {
     return totalBurned;
    }
 
    function getTotalRewardsGiven() external view returns (uint256) {
     return totalRewardsGiven;
    }

    function getMaxBurn() external view returns (uint256) {
     return MAX_BURN;
    }

    modifier checkTransactionDelay() {
        require(
            _lastTransactionTime[msg.sender] + TRANSACTION_DELAY <= block.timestamp,
            "Transacation cooldown period has not passed"
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

    modifier checkStakingRewards(uint256 reward) {
    require(totalRewardsGiven + reward <= STAKING_ALLOCATION, "Total staking rewards exceeded");
    _;
   }

   modifier checkIsAirDropReedemable() {
    require(_canRedeem[msg.sender] == true, "You are whitelisted for airdop");
    _;
   }
}
