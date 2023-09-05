// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SpunkySDX is Ownable, ReentrancyGuard {
    // Token details
    string public name;
    string public symbol;
    uint8 public _decimals;
    uint256 public totalSupply;

    // Token balances
    mapping(address => uint256) private _balances;
    mapping(address => mapping(uint8 => uint256)) private _allocationBalances;

    // Define the staking plans
    enum StakingPlan {
        ThirtyDays,
        NinetyDays,
        OneEightyDays,
        ThreeSixtyDays,
        Flexible
    }

    // Define the returns for each plan
    mapping(StakingPlan => uint256) private _stakingPlanReturns;

    // Define the duration for each plan
    mapping(StakingPlan => uint256) private _stakingPlanDurations;

    // Token allowances
    mapping(address => mapping(address => uint256)) private _allowances;

    // Staking details
    mapping(address => mapping(StakingPlan => uint256))
        private _stakingBalances;
    mapping(address => mapping(StakingPlan => uint256)) private _stakingRewards;
    mapping(address => mapping(StakingPlan => uint256))
        private _accruedStakingRewards;
    mapping(address => mapping(StakingPlan => uint256))
        private _stakingStartTimes;
    // To map the index index  of each Staking Plan to users address
    mapping(address => mapping(StakingPlan => uint256))
        private _stakingDetailsIndex;

    // staking details
    struct StakingDetail {
        address owner;
        uint256 amount;
        uint256 startTime;
        StakingPlan plan;
        uint256 reward;
        uint256 accruedReward;
        bool isActive;
    }

    StakingDetail[] private _stakingDetails;

    // Vesting details
    mapping(address => VestingDetail[]) private _vestingDetails;

    struct VestingDetail {
        address vestOwner;
        uint256 amount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 releasedAmount;
    }
    address[] public vestingAccounts;
    // Fixed price for buying tokens during the presale (in wei per token)
    uint256 public presalePrice = 1;

    AggregatorV3Interface public priceFeed;

    // State to determine if the contract is in presale or launch state
    bool public isPresale = true;

    // Token distribution details
    uint256 private WHITELIST_ALLOCATION = 0;
    uint256 private PRESALE_ALLOCATION = 0;
    uint256 private IEO_ALLOCATION = 0;
    uint256 private AIRDROP_ALLOCATION = 0;
    uint256 private TEAM_ALLOCATION = 0;
    uint256 private STAKING_ALLOCATION = 0;
    uint256 private INVESTORS_ALLOCATION = 0;

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Stake(address indexed user, uint256 amount, StakingPlan plan);
    event UpdateStake(address indexed user, uint256 amount, StakingPlan plan);
    event Unstake(address indexed user, uint256 amount, StakingPlan plan);
    event ClaimRewards(address indexed user, uint256 reward);
    event VestingScheduleAdded(
        address indexed account,
        uint256 amount,
        uint256 startTime,
        uint256 cliff,
        uint256 VestedDuration
    );
    event Burn(address indexed account, uint256 amount);
    event TokensReleased(address indexed account, uint256 amount);
    event BuyTokens(uint256 amount);

    constructor() {
        name = "Spunky0123";
        symbol = "SP0123";
        _decimals = 18;
        totalSupply = 500e9 * 10 ** uint256(_decimals);
        // Initially assign all tokens to the contract itself
        _balances[address(this)] = totalSupply;

        //Chainlink Aggregator contract address
        priceFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );

        // Token distribution details based on total supply
        WHITELIST_ALLOCATION = (totalSupply * 2) / 100; // 2% of total supply
        PRESALE_ALLOCATION = (totalSupply * 20) / 100; // 20% of total supply
        IEO_ALLOCATION = (totalSupply * 8) / 100; // 8% of total supply
        AIRDROP_ALLOCATION = (totalSupply * 4) / 100; // 4% of total supply
        TEAM_ALLOCATION = (totalSupply * 6) / 100; // 6% of total supply
        STAKING_ALLOCATION = (totalSupply * 15) / 100; // 15% of total supply
        INVESTORS_ALLOCATION = (totalSupply * 5) / 100; // 5% of total supply
        MAX_BURN = (totalSupply * 10) / 100; // 10% of total supply

        // Define the returns for each staking plan
        _stakingPlanReturns[StakingPlan.ThirtyDays] = 5;
        _stakingPlanReturns[StakingPlan.NinetyDays] = 10;
        _stakingPlanReturns[StakingPlan.OneEightyDays] = 30;
        _stakingPlanReturns[StakingPlan.ThreeSixtyDays] = 50;
        _stakingPlanReturns[StakingPlan.Flexible] = 1;

        // Initialize the durations for each staking plan
        _stakingPlanDurations[StakingPlan.ThirtyDays] = 30;
        _stakingPlanDurations[StakingPlan.NinetyDays] = 90;
        _stakingPlanDurations[StakingPlan.OneEightyDays] = 180;
        _stakingPlanDurations[StakingPlan.ThreeSixtyDays] = 360;
        _stakingPlanDurations[StakingPlan.Flexible] = 2;

        // Allocate tokens for the whitelist, presale, airdrop and IEO
        _allocationBalances[address(this)][1] = WHITELIST_ALLOCATION;
        _allocationBalances[address(this)][2] = PRESALE_ALLOCATION;
        _allocationBalances[address(this)][3] = IEO_ALLOCATION;
        _allocationBalances[address(this)][4] = AIRDROP_ALLOCATION;
        _allocationBalances[address(this)][5] = TEAM_ALLOCATION;
        _allocationBalances[address(this)][6] = STAKING_ALLOCATION;
        _allocationBalances[address(this)][7] = INVESTORS_ALLOCATION;
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

    function getSupply() public view returns (uint256) {
        return totalSupply;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allocationBalance(
        address account,
        uint8 allocation
    ) public view returns (uint256) {
        require(allocation >= 1 && allocation <= 6, "Invalid allocation");
        return _allocationBalances[account][allocation];
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
            uint256 taxAmount = (amount * SELL_TAX_PERCENTAGE) / 100;
            amount -= taxAmount;
            _transfer(msg.sender, owner(), taxAmount);
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

    function setCanRedeemAirdrop(
        address[] calldata airdropRecipients,
        bool canRedeem
    ) external nonReentrant onlyOwner {
        for (uint256 i = 0; i < airdropRecipients.length; i++) {
            _canRedeem[airdropRecipients[i]] = canRedeem;
        }
    }

    function redeemAirdrop(
        uint256 amount
    )
        external
        nonReentrant
        checkMaxHolding(msg.sender, amount)
        checkIsAirDropReedemable
    {
        require(!_airdropRedeemed[msg.sender], "Airdrop already redeemed");
        require(amount > 0, "Invalid amount");
        require(
            _allocationBalances[address(this)][4] >= amount,
            "No airdrop balance available"
        );
        _airdropRedeemed[msg.sender] = true;
        _allocationBalances[address(this)][4] -= amount;
        uint256 immediateAmount = (amount * 2) / 100; // 2% sent to users
        uint256 vestedAmount = (amount * 98) / 100; // 98% vested for users
        uint256 cliffDuration = 30 days * 6; // 6 months cliff
        uint256 vestingDuration = 30 days * 98; // 1 percent per month
        _transfer(address(this), msg.sender, immediateAmount);
        addVestingSchedule(
            msg.sender,
            vestedAmount,
            cliffDuration,
            vestingDuration
        );
    }

    function addVestByOwner(
        address account,
        uint256 amount,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) public onlyOwner {
        _transfer(msg.sender, address(this), amount);
        addVestingSchedule(account, amount, cliffDuration, vestingDuration);
    }

    function addVestingSchedule(
        address account,
        uint256 amount,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) internal {
        // i removed the nonReentrant onthis function since it internal
        require(account != address(0), "Invalid account");
        require(amount > 0, "Invalid amount");
        require(
            cliffDuration < vestingDuration,
            "Cliff duration must be less than vesting duration"
        );
        require(
            _balances[owner()] >= amount,
            "Owner does not have enough balance"
        );
        VestingDetail memory newVesting = VestingDetail({
            vestOwner: msg.sender,
            amount: amount,
            startTime: block.timestamp,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            releasedAmount: 0
        });
        _vestingDetails[account].push(newVesting);
        emit VestingScheduleAdded(
            account,
            amount,
            block.timestamp,
            cliffDuration,
            vestingDuration
        );
    }

    // Function to release vested tokens
    function releaseVestedTokens(address account) public nonReentrant {
        require(account != address(0), "Invalid account");
        VestingDetail[] storage vestingDetails = _vestingDetails[account];
        for (uint256 i = 0; i < vestingDetails.length; i++) {
            VestingDetail storage vesting = vestingDetails[i];
            if (
                vesting.amount > 0 &&
                vesting.amount > vesting.releasedAmount &&
                block.timestamp >= vesting.startTime + vesting.cliffDuration
            ) {
                release(account, vesting);
            }
        }
    }

    // Internal function to release vested tokens for a specific vesting detail
    function release(address account, VestingDetail storage vesting) internal {
        require(
            block.timestamp >= vesting.startTime + vesting.cliffDuration,
            "Cliff period has not ended"
        );

        require(
            vesting.releasedAmount < vesting.amount,
            "No tokens to release"
        );

        uint256 elapsedTime = block.timestamp -
            (vesting.startTime + vesting.cliffDuration);

        // If elapsed time is greater than vesting duration, set it equal to vesting duration
        elapsedTime = (elapsedTime > vesting.vestingDuration)
            ? vesting.vestingDuration
            : elapsedTime;

        // Calculate the total vested amount till now
        uint256 totalVestedAmount = (vesting.amount * elapsedTime) /
            vesting.vestingDuration;

        // Calculate the amount that is yet to be released
        uint256 unreleasedAmount = totalVestedAmount - vesting.releasedAmount;

        require(unreleasedAmount > 0, "No tokens to release");

        // Update the released amount
        vesting.releasedAmount += unreleasedAmount;

        // Transfer the tokens
        _transfer(address(this), account, unreleasedAmount);

        emit TokensReleased(account, unreleasedAmount);
    }

    function getNumberOfVestingSchedules(
        address account
    ) public view returns (uint256) {
        return _vestingDetails[account].length;
    }

    function getVestingDetails(
        address account
    ) public view returns (VestingDetail[] memory) {
        return _vestingDetails[account];
    }

    function calculateStakingReward(
        uint256 amount,
        StakingPlan plan
    ) internal view returns (uint256) {
        require(amount > 0, "Invalid staking amount");
        uint256 rewardPercentage = _stakingPlanReturns[plan];

        if (plan == StakingPlan.Flexible) {
            return 0;
        }

        return (amount * rewardPercentage) / 1000;
    }

    function calculateAccruedReward(
        uint256 amount,
        StakingPlan plan
    ) internal view returns (uint256) {
        require(amount > 0, "Invalid staking amount");
        uint256 rewardPercentage = _stakingPlanReturns[plan];
        uint256 rewardDurationTime = _stakingPlanDurations[plan] * 1 days;
        uint256 elapseTime = (block.timestamp -
            _stakingStartTimes[msg.sender][plan]);

        if (elapseTime > rewardDurationTime && plan != StakingPlan.Flexible) {
            elapseTime = rewardDurationTime;
        }

        // Total days accrued in relation to 365 days (1 year);
        uint256 daysRatio = elapseTime / 365 days;

        return (amount * rewardPercentage * daysRatio) / 1000;
    }

    function stake(
        uint256 amount,
        StakingPlan plan
    ) external nonReentrant checkMaxHolding(msg.sender, amount) {
        require(amount > 0, "Invalid staking amount");
        require(
            _stakingBalances[msg.sender][plan] == 0,
            "user alread staking add to your stake or unstake"
        );

        uint256 reward = calculateStakingReward(amount, plan);

        require(
            _allocationBalances[address(this)][6] >= reward,
            "Staking rewards exhausted"
        );

        _transfer(msg.sender, address(this), amount);

        _stakingBalances[msg.sender][plan] = amount;
        _stakingStartTimes[msg.sender][plan] = block.timestamp;
        _stakingRewards[msg.sender][plan] = reward;
        _accruedStakingRewards[msg.sender][plan] = 0;

        _allocationBalances[address(this)][6] -= reward; // Decrement the staking allocation balance
        StakingDetail memory newStaking = StakingDetail({
            owner: msg.sender,
            amount: amount,
            startTime: block.timestamp,
            plan: plan,
            reward: reward,
            accruedReward: 0,
            isActive: true
        });
        _stakingDetailsIndex[msg.sender][plan] = _stakingDetails.length;
        _stakingDetails.push(newStaking);
        emit Stake(msg.sender, amount, plan);
    }

    function addToStake(
        uint256 additionalAmount,
        StakingPlan plan
    ) external nonReentrant {
        require(additionalAmount > 0, "Invalid additional staking amount");
        require(
            _stakingBalances[msg.sender][plan] > 0,
            "No existing stake found"
        );

        // Record any accrued rewards first
        uint256 accruedReward = calculateAccruedReward(
            _stakingBalances[msg.sender][plan],
            plan
        );
        _accruedStakingRewards[msg.sender][plan] += accruedReward;

        // Update the staking balance and start time
        _stakingBalances[msg.sender][plan] += additionalAmount;
        _stakingStartTimes[msg.sender][plan] = block.timestamp;

        // Calculate the new reward and update the reward balance
        uint256 newReward = calculateStakingReward(
            _stakingBalances[msg.sender][plan],
            plan
        );

        // adjust allocation balance to update
        _allocationBalances[address(this)][6] += _stakingRewards[msg.sender][
            plan
        ];
        _allocationBalances[address(this)][6] -= accruedReward;
        _allocationBalances[address(this)][6] -= newReward;

        // Transfer the additional staked amount from the user to the contract
        _transfer(msg.sender, address(this), additionalAmount);

        // update staking details
        uint256 detailsIndex = _stakingDetailsIndex[msg.sender][plan];
        _stakingDetails[detailsIndex] = StakingDetail({
            owner: msg.sender,
            amount: _stakingBalances[msg.sender][plan],
            startTime: block.timestamp,
            plan: plan,
            reward: newReward,
            accruedReward: _accruedStakingRewards[msg.sender][plan],
            isActive: true
        });

        // emit update
        emit UpdateStake(msg.sender, _stakingBalances[msg.sender][plan], plan);
    }

    function claimReward(StakingPlan plan) internal {
        require(msg.sender != owner(), "Owner can not stake");
        require(
            _stakingBalances[msg.sender][plan] > 0,
            "No staking balance available"
        );

        uint256 amount = _stakingBalances[msg.sender][plan];
        uint256 reward = _accruedStakingRewards[msg.sender][plan];

        // Check if the unstaking request is made after the plan duration
        bool isAfterPlanDuration = block.timestamp >=
            _stakingStartTimes[msg.sender][plan] +
                _stakingPlanDurations[plan] *
                1 days;

        // If it's a Flexible plan or after the plan duration for other plans, calculate the reward
        if (plan == StakingPlan.Flexible) {
            require(isAfterPlanDuration, "Cannot unstake before 48 hours");
            uint256 addedReward = calculateAccruedReward(amount, plan);
            // update allocation balance
            _allocationBalances[address(this)][6] -= addedReward;
            reward += calculateAccruedReward(amount, plan);
        } else {
            require(isAfterPlanDuration, "Cannot unstake before duration");
            reward += _stakingRewards[msg.sender][plan];
        }
        // If unstaking before the plan duration for non-flexible plans, reward remains 0

        _transfer(address(this), msg.sender, reward); // Include reward in the transfer
        _accruedStakingRewards[msg.sender][plan] = 0;

        uint256 newReward = calculateStakingReward(
            _stakingBalances[msg.sender][plan],
            plan
        );

        // First add the previous calculated reward to allocation
        _allocationBalances[address(this)][6] += _stakingRewards[msg.sender][
            plan
        ];
        // First subtract the current calculated reward to allocation
        _allocationBalances[address(this)][6] -= newReward;

        uint256 detailsIndex = _stakingDetailsIndex[msg.sender][plan];
        _stakingDetails[detailsIndex] = StakingDetail({
            owner: msg.sender,
            amount: _stakingBalances[msg.sender][plan],
            startTime: block.timestamp,
            plan: plan,
            reward: newReward,
            accruedReward: 0,
            isActive: true
        });

        // emit update
        emit UpdateStake(msg.sender, _stakingBalances[msg.sender][plan], plan);
        //  emit claim reward
        emit ClaimRewards(msg.sender, reward);
    }

    function userClaimReward(StakingPlan plan) external nonReentrant {
        claimReward(plan);
    }

    function unstake(StakingPlan plan) external nonReentrant {
        require(msg.sender != owner(), "Owner can not stake");
        require(
            _stakingBalances[msg.sender][plan] > 0,
            "No staking balance available"
        );

        uint256 amount = _stakingBalances[msg.sender][plan];

        // call claim
        claimReward(plan);
        _transfer(address(this), msg.sender, amount); // transfer only amount to user
        _stakingBalances[msg.sender][plan] = 0;
        _stakingRewards[msg.sender][plan] = 0;
        _accruedStakingRewards[msg.sender][plan] = 0;

        uint256 detailsIndex = _stakingDetailsIndex[msg.sender][plan];
        _stakingDetails[detailsIndex] = StakingDetail({
            owner: msg.sender,
            amount: 0,
            startTime: block.timestamp,
            plan: plan,
            reward: 0,
            accruedReward: 0,
            isActive: false
        });
        emit UpdateStake(msg.sender, 0, plan);
        emit Unstake(msg.sender, amount, plan);
    }

    function getUserStakingDetails(
        StakingPlan plan
    ) external view returns (StakingDetail memory) {
        uint256 detailsIndex = _stakingDetailsIndex[msg.sender][plan];
        return _stakingDetails[detailsIndex];
    }

    function isSellTransaction(address recipient) internal view returns (bool) {
        return recipient == address(this);
    }

    function burn(uint256 amount) public onlyOwner {
        require(
            totalBurned + amount <= MAX_BURN,
            "Total burned exceeds max burn amount"
        );
        require(amount <= _balances[msg.sender], "Not enough tokens to burn");
        _balances[msg.sender] -= amount;
        totalSupply -= amount;
        totalBurned += amount;
        emit Transfer(msg.sender, address(0), amount);
        emit Burn(msg.sender, amount);
    }

    function buyTokens()
        internal
        checkMaxHolding(msg.sender, balanceOf(msg.sender))
    {
        require(msg.value > 0, "No Ether sent");
        require(msg.sender != owner(), "Contract owner cannot participate");

        // Check if the presale is ongoing
        if (isPresale == true) {
            uint256 ethPrice = getETHPrice(); // Get the current ETH price in USD
            require(msg.sender != owner(), "Contract owner cannot participate");
            uint256 tokensToBuy = (msg.value * ethPrice * presalePrice) / 10000;

            // Check if the presale allocation is sufficient
            require(
                _allocationBalances[address(this)][2] >= tokensToBuy,
                "Not enough presale tokens available"
            );

            // Calculate vested amounts
            uint256 immediateReleaseAmount = (tokensToBuy * 1) / 4;
            uint256 vestedAmount = (tokensToBuy * 3) / 4; // 75%

            // Update the presale allocation
            _allocationBalances[address(this)][2] -= tokensToBuy;

            // Transfer the immediate release portion to buyer
            _transfer(address(this), msg.sender, immediateReleaseAmount);

            // Set up the vesting schedule for the user's vested amount, over 5 months
            uint256 cliffDuration = 0; // No cliff for presale
            uint256 vestingDuration = 30 days * 5; // 5 months
            addVestingSchedule(
                msg.sender,
                vestedAmount,
                cliffDuration,
                vestingDuration
            );
            emit BuyTokens(_allocationBalances[address(this)][2]);
        } else {
            // If the presale is over, refund the Ether
            payable(msg.sender).transfer(msg.value);
        }
    }

    receive() external payable {
        buyTokens();
    }

    function getETHPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price feed");
        return uint256(price);
    }

    function withdrawToken(
        address tokenAddress,
        uint256 tokenAmount
    ) external onlyOwner {
        require(isPresale == false, "Presale has ended");

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

    function endPresale() external onlyOwner {
        isPresale = false;
    }

    function renounceOwnership() public override onlyOwner {
        // Prevent renouncing ownership if there are staking rewards available
        super.renounceOwnership();
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        require(
            _stakingRewards[msg.sender][StakingPlan.ThirtyDays] == 0,
            "Staking rewards must be claimed before renouncing ownership"
        );
        require(
            _stakingRewards[msg.sender][StakingPlan.NinetyDays] == 0,
            "Staking rewards must be claimed before renouncing ownership"
        );
        require(
            _stakingRewards[msg.sender][StakingPlan.OneEightyDays] == 0,
            "Staking rewards must be claimed before renouncing ownership"
        );
        require(
            _stakingRewards[msg.sender][StakingPlan.ThreeSixtyDays] == 0,
            "Staking rewards must be claimed before renouncing ownership"
        );
        require(
            _stakingRewards[msg.sender][StakingPlan.Flexible] == 0,
            "Staking rewards must be claimed before renouncing ownership"
        );
        super.transferOwnership(newOwner);
    }

    function getStakingAllocation() public view returns (uint256) {
        return _allocationBalances[address(this)][6];
    }

    function getPresaleState() public view returns (bool) {
        return isPresale;
    }

    function getPresalePrice() public view returns (uint256) {
        return presalePrice;
    }

    function getPresaleAllocation() public view returns (uint256) {
        return _allocationBalances[address(this)][2];
    }

    function getAirdropAllocation() public view returns (uint256) {
        return _allocationBalances[address(this)][4];
    }

    function getTotalBurned() public view returns (uint256) {
        return totalBurned;
    }

    function getTotalRewardsGiven() public view returns (uint256) {
        return totalRewardsGiven;
    }

    function getMaxBurn() public view returns (uint256) {
        return MAX_BURN;
    }

    function getCanRedeem() public view returns (bool) {
        return _canRedeem[msg.sender];
    }

    function getHasRedeemed() public view returns (bool) {
        return _airdropRedeemed[msg.sender];
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
        if (recipient != address(this) && recipient != owner()) {
            require(
                (_balances[recipient] + amount) <=
                    ((totalSupply * MAX_HOLDING_PERCENTAGE) / 100),
                "Recipient's token holding exceeds the maximum allowed percentage"
            );
        }
        _;
    }
    modifier checkStakingRewards(uint256 reward) {
        require(
            totalRewardsGiven + reward <= STAKING_ALLOCATION,
            "Total staking rewards exceeded"
        );
        _;
    }
    modifier checkIsAirDropReedemable() {
        require(
            _canRedeem[msg.sender] == true,
            "You are not whitelisted for airdop"
        );
        _;
    }
}
