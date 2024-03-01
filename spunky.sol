// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;



library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}


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

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
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


contract SpunkyStaking is Ownable, ReentrancyGuard {
   using SafeERC20 for IERC20;

    string public name;

    // Define the staking plans
    enum StakingPlan {
        ThirtyDays,
        NinetyDays,
        OneEightyDays,
        ThreeSixtyDays,
        Flexible
    }

    enum RewardCalculationType {
        Initial,
        Accrued
    }

    // Define the returns for each plan
    mapping(StakingPlan => uint256) private _stakingPlanReturns;

    // Define the duration for each plan
    mapping(StakingPlan => uint256) private _stakingPlanDurations;

    // Total staked amount
    uint256 private _totalStakedAmount = 0;
    uint256 private _rewardBalance;

    // Calculate 5% of the total supply
    uint256 private constant MAX_HOLDING = (500 * (10 ** 9) * (10 ** 18) * 5) / 100;

    IERC20 public spunkyToken;

    // Staking details
    struct UserStake {
        uint256 index;
        address owner;
        uint256 amount;
        uint256 startTime;
        StakingPlan plan;
        uint256 reward;
        uint256 accruedReward;
        bool isActive;
    }

    UserStake[] private _stakingDetails;
    mapping(address => mapping(StakingPlan => UserStake)) private _userStakes;

    // Events
    event Stake(address indexed user, uint256 amount, StakingPlan plan);
    event UpdateStake(address indexed user, uint256 newAmount, StakingPlan plan);
    event ClaimRewards(address indexed user, uint256 reward);
    event Unstake(address indexed user, uint256 amount, StakingPlan plan);
    event EmergencyWithdraw(address indexed user, uint256 amount, StakingPlan plan);

    constructor(address _spunkyTokenAddress) {
        name = "SpunkySDXStaking";
        spunkyToken = IERC20(_spunkyTokenAddress); // Initialize the spunkyToken state variable
    
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
    }

function stake(uint256 amount, StakingPlan plan) public nonReentrant {
    require(amount > 0, "The staking amount must be greater than zero.");
    UserStake storage userStake = _userStakes[msg.sender][plan];
    require(userStake.amount == 0, "User already staking; add to your stake or unstake.");
    require(!userStake.isActive, "Plan is already active");

    // Transfer tokens from the user to this contract and calculate the actual amount received
    uint256 balanceBefore = IERC20(spunkyToken).balanceOf(address(this));
    IERC20(spunkyToken).safeTransferFrom(msg.sender, address(this), amount);
    uint256 balanceAfter = IERC20(spunkyToken).balanceOf(address(this));
    uint256 actualAmount = balanceAfter - balanceBefore;

    // Update total staked amount
    _totalStakedAmount += actualAmount;

    // Calculate reward based on actualAmount
    uint256 reward = calculateStakingReward(actualAmount, plan);
    
    require(_rewardBalance >= reward, "Staking rewards exhausted");

    // Update stake details
    userStake.owner = msg.sender;
    userStake.amount = actualAmount; // Use actualAmount here
    userStake.startTime = block.timestamp;
    userStake.plan = plan;
    userStake.reward = reward;
    userStake.accruedReward = 0;
    userStake.index = _stakingDetails.length;
    userStake.isActive = true;

    _stakingDetails.push(userStake);

    emit Stake(msg.sender, actualAmount, plan); // Emit actualAmount
}


function addToStake(uint256 additionalAmount, StakingPlan plan) public nonReentrant {
    require(additionalAmount > 0, "Invalid additional staking amount");


    UserStake storage userStake = _userStakes[msg.sender][plan];

    // Ensure the user has an active stake to add to
    require(userStake.amount > 0, "No existing stake found.");
    require(userStake.isActive, "Stake is not active.");

    // Transfer the additional amount to the contract
    uint256 balanceBefore = spunkyToken.balanceOf(address(this));
    spunkyToken.safeTransferFrom(msg.sender, address(this), additionalAmount);
    uint256 balanceAfter = spunkyToken.balanceOf(address(this));
    uint256 actualAdditionalAmount = balanceAfter - balanceBefore;

    uint256 newStakeAmount = userStake.amount + actualAdditionalAmount;

    uint256 newReward = calculateStakingReward(newStakeAmount, plan);
    uint256 newAccruedReward = calculateAccruedReward(userStake.amount, plan);

    // Check if the new reward exceeds the available _rewardBalance
    require(_rewardBalance >= newReward + newAccruedReward, "Insufficient reward balance for the new stake amount.");

    userStake.reward = newReward;
    userStake.accruedReward += newAccruedReward;
    userStake.amount = newStakeAmount;
    userStake.startTime = block.timestamp;

    // Update the _stakingDetails array
    UserStake storage detail = _stakingDetails[userStake.index];
    detail.amount = newStakeAmount;
    detail.reward = newReward;
    detail.accruedReward += newAccruedReward;
    detail.startTime = block.timestamp;

    // Update the total staked amount and _rewardBalance
    _totalStakedAmount += actualAdditionalAmount;

    require (newStakeAmount <= MAX_HOLDING, "You cannot hold above the maximum amount");

    emit UpdateStake(msg.sender, newStakeAmount, plan);
}


    // Add a function to allow the owner to fund the reward balance
    function fundRewards(uint256 amount) public onlyOwner nonReentrant {
    uint256 balanceBefore = IERC20(spunkyToken).balanceOf(address(this));
    IERC20(spunkyToken).transferFrom(msg.sender, address(this), amount);
    uint256 balanceAfter = IERC20(spunkyToken).balanceOf(address(this));
    uint256 actualReceivedAmount = balanceAfter - balanceBefore;

    // Handle deflationary token's transaction fee
    require(actualReceivedAmount > 0, "Received amount is zero");

    _rewardBalance += actualReceivedAmount;
    }


function claimReward(StakingPlan plan) internal returns (uint256) {
    UserStake memory userStake = _userStakes[msg.sender][plan];
    require(userStake.amount > 0, "No staking balance available");

    uint256 reward = userStake.reward + userStake.accruedReward;

    if (plan == StakingPlan.Flexible) {
        uint256 addedReward = calculateAccruedReward(userStake.amount, plan);
        reward += addedReward;

        // Adjust reward if it exceeds the available _rewardBalance
        if (_rewardBalance < reward){
            reward = _rewardBalance;
        }
    }

    uint256 totalBalance = userStake.amount + reward;
    if (totalBalance > MAX_HOLDING) {
        reward = MAX_HOLDING - userStake.amount;
    }

    require(_rewardBalance >= reward, "Insufficient reward balance");
    _rewardBalance -= reward;

    return reward;
}


  function userClaimReward(StakingPlan plan) public nonReentrant {
    // Retrieve the user's stake details from storage
    UserStake storage userStake = _userStakes[msg.sender][plan];

    // Calculate the duration condition for reward claiming
    bool isAfterPlanDuration = block.timestamp >=
        userStake.startTime + _stakingPlanDurations[plan] * 1 days;

    // Ensure the user is allowed to claim the reward
    require(
        isAfterPlanDuration,
        "Cannot claim rewards before the staking duration expires"
    );

    // Retrieve the total reward for the user
    uint256 reward = claimReward(plan);

    // Transfer the reward to the user
    IERC20(spunkyToken).safeTransfer(msg.sender, reward);

    // Reset the accrued reward and startTime for the user
    userStake.accruedReward = 0;
    userStake.startTime = block.timestamp;

    // Update the stakingDetails array to reflect the new accruedReward and startTime
    _stakingDetails[userStake.index].accruedReward = 0;
    _stakingDetails[userStake.index].startTime = block.timestamp;

    // Emit a ClaimRewards event
    emit ClaimRewards(msg.sender, reward);
}


    function removeStakeFromArray(StakingPlan plan) internal {
        // Retrieve the stake details for the user
        UserStake storage userStake = _userStakes[msg.sender][plan];

        // Ensure the user has an active stake for this plan
        require(userStake.isActive, "You don't have a stake for this plan");

        // Get the last index in the staking details array
        uint256 lastIndex = _stakingDetails.length - 1;

        // If the stake to be removed is not the last one, swap it with the last one
        if (userStake.index != lastIndex) {
            UserStake memory swappedStake = _stakingDetails[lastIndex];

            // Perform the swap
            _stakingDetails[userStake.index] = swappedStake;

            // Update the index for the stake that was moved
            _userStakes[swappedStake.owner][swappedStake.plan].index = userStake
                .index;
        }

        // Remove the last element (which is now the element to be removed)
        _stakingDetails.pop();

        // Delete the user's stake information
        delete _userStakes[msg.sender][plan];
    }

   function unstake(StakingPlan plan) public nonReentrant {
    require(msg.sender == owner(), "You own no rights to unstake this stake");
    UserStake storage userStake = _userStakes[msg.sender][plan];
    require(userStake.amount > 0, "No staking balance available");

    // Check if the staking period has ended
    if (plan == StakingPlan.Flexible) {
        // For the flexible plan, require at least 48 hours before unstaking
        require(block.timestamp >= userStake.startTime + 2 days, "Minimum staking period for flexible plan has not ended");
    } else {
        require(block.timestamp >= userStake.startTime + _stakingPlanDurations[plan] * 1 days, "Staking period has not ended");
    }

    bool isAfterPlanDuration = block.timestamp >=
        userStake.startTime + _stakingPlanDurations[plan] * 1 days;

    uint256 reward = claimReward(plan);

    if (!isAfterPlanDuration) {
        // If the unstaking is done before the plan duration, the reward is forfeited
        reward = 0;
    }

    uint256 totalAmount = userStake.amount + reward;

    // Transfer the unstaked amount and reward back to the user
        IERC20(spunkyToken).safeTransfer(msg.sender, totalAmount);

    // Update the total staked amount
    _totalStakedAmount -= userStake.amount;

    // Emit an Unstake event
    emit Unstake(msg.sender, userStake.amount, plan);

    // Remove the user's stake details
    removeStakeFromArray(plan);
}

    function getCanClaimStakingReward(
        StakingPlan plan
    ) external view returns (bool) {
        uint256 stakingStartTime = _userStakes[msg.sender][plan].startTime;
        bool isAfterPlanDuration = block.timestamp >=
            stakingStartTime + _stakingPlanDurations[plan] * 1 days;
        return isAfterPlanDuration;
    }

    function getIsStakingActive(StakingPlan plan) public view returns (bool) {
        return _userStakes[msg.sender][plan].isActive;
    }

    function getStakingDetailsCount() public view returns (uint256) {
        return _stakingDetails.length;
    }

    function getTotalStakedAmount() public view returns (uint256) {
        return _totalStakedAmount;
    }

    function getStakingBalance(
        StakingPlan plan
    ) public view returns (uint256) {
        return _userStakes[msg.sender][plan].amount;
    }

    function getStakingReward(
        StakingPlan plan
    ) public view returns (uint256) {
        // Fetch the user's stake details
        UserStake memory userStake = _userStakes[msg.sender][plan];

        // If the plan is not active for the user, return zero
        if (!userStake.isActive) {
            return 0;
        }

         // If the allocation balance is zero, return zero
        if (IERC20(spunkyToken).balanceOf(address(this))  == 0) {
            return 0;
        }

        // Otherwise, calculate the total reward
        uint256 additional = calculateAccruedReward(userStake.amount, plan);
        return userStake.accruedReward + additional;
    }

    function getAllStakingBalances(
        address user
    ) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](5); // Assuming 5 plans
        balances[0] = _userStakes[user][StakingPlan.ThirtyDays].amount;
        balances[1] = _userStakes[user][StakingPlan.NinetyDays].amount;
        balances[2] = _userStakes[user][StakingPlan.OneEightyDays].amount;
        balances[3] = _userStakes[user][StakingPlan.ThreeSixtyDays].amount;
        balances[4] = _userStakes[user][StakingPlan.Flexible].amount;
        return balances;
    }

    function getStakingDetailsPage(
    uint256 start,
    uint256 end
) public view returns (UserStake[] memory) {
    // Validate the indices
    require(
        start <= end && end < _stakingDetails.length,
        "Invalid indices"
    );

    // Limit the number of iterations to 100
    require(
        end - start <= 100,
        "Too many iterations"
    );

    // Create a new array to hold the range of UserStakes
    UserStake[] memory page = new UserStake[](end - start + 1);

    // Loop through the _stakingDetails array and populate the 'page' array
    for (uint256 i = start; i <= end; i++) {
        page[i - start] = _stakingDetails[i];
    }

    // Return the 'page' array
    return page;
}

    function calculateStakingReward(
    uint256 amount,
    StakingPlan plan
    )internal view returns (uint256) {
    require(amount > 0, "Invalid staking amount");
    uint256 rewardPercentage = _stakingPlanReturns[plan];
    uint256 daysRequired = _stakingPlanDurations[plan];

    if (plan == StakingPlan.Flexible) {
        return 0;
    } else {
        return (amount * rewardPercentage * daysRequired) / (1000 * 365);
    }
    }


    function calculateAccruedReward(
    uint256 amount,
    StakingPlan plan
) internal view returns (uint256) {
    require(amount > 0, "Invalid staking amount");
    uint256 startTime = _userStakes[msg.sender][plan].startTime;
    uint256 rewardPercentage = _stakingPlanReturns[plan];
    uint256 elapseTime = block.timestamp - startTime;
    uint256 durationInSeconds = _stakingPlanDurations[plan] * 1 days;
    uint256 secondsInAYear = 365 * 1 days;

    if (elapseTime > durationInSeconds && plan != StakingPlan.Flexible) {
        elapseTime = durationInSeconds;
    }

    if (plan == StakingPlan.Flexible) {
        // Adjusting the reward calculation for the Flexible plan to 0.1% APY
        return (amount * elapseTime) / (1000 * secondsInAYear);
    } else {
        // For other plans, the formula remains the same:
        return (amount * rewardPercentage * elapseTime) / (1000 * secondsInAYear);
    }
}

    function calculateReward (
        uint256 amount,
        StakingPlan plan,
        RewardCalculationType calculationType,
        uint256 startTime //Used primarily for reward calculation
    ) internal view returns (uint256) {
        uint256 rewardPercentage = _stakingPlanReturns[plan];
        uint256 durationInSeconds = _stakingPlanDurations[plan] * 1 days;
        uint256 secondsInAYear = 365 * 1 days;
        
        if (calculationType == RewardCalculationType.Initial) {
            // For initial reward calculation
            if (plan == StakingPlan.Flexible) {
                return 0; // Flexible plan might have different handling
            } else {
                require(amount > 0, "Invalid staking amount");
                return (amount * rewardPercentage * durationInSeconds) / (1000 * secondsInAYear);
            }
        } else {
            // For accrued reward calculation
            require(amount > 0, "Invalid staking amount");
            uint256 elapseTime = block.timestamp - startTime;
            if (elapseTime > durationInSeconds && plan != StakingPlan.Flexible) {
                elapseTime = durationInSeconds;
            }
            if (plan == StakingPlan.Flexible) {
                // Adjusting the reward calculation for the Flexible plan
                return (amount * elapseTime) / (1000 * secondsInAYear);
            } else {
                return (amount * rewardPercentage * elapseTime) / (1000 * secondsInAYear);
            }
        }

    }

function emergencyWithdraw(StakingPlan plan) public nonReentrant {
    require(msg.sender == owner(), "Only owner can call an emergency withdrawal");
    UserStake storage userStake = _userStakes[msg.sender][plan];
    require(userStake.amount > 0, "No staking balance available");

    // Ensure that emergency withdrawal is done before the plan ends
    bool isBeforePlanEnds = block.timestamp < userStake.startTime + _stakingPlanDurations[plan] * 1 days;
    require(isBeforePlanEnds, "Emergency withdrawal is allowed only before the plan ends");

    uint256 totalAmount = userStake.amount;

    // Transfer the unstaked amount back to the user
    IERC20(spunkyToken).safeTransfer(msg.sender, totalAmount);

    // Update the total staked amount
    _totalStakedAmount -= userStake.amount;
    
    // Emit an EmergencyWithdraw event
    emit EmergencyWithdraw(msg.sender, totalAmount, plan);

    // Remove the user's stake details
    delete _userStakes[msg.sender][plan];
}


    
}
