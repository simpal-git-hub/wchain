// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Importing the Token contract and IERC20 interface from OpenZeppelin
import "./Token.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Main contract inheriting from the Token contract
contract Dapp is Token {
    address public owner; // owner of the contract
    IERC20 public rewardToken; // The reward token used in the contract

    // Struct to define the properties of each staking tier
    struct StakingTier {
        uint256 rewardPercentage; // The reward rate for the tier (in basis points)
        uint256 lockDuration;    // Lock duration for the tier (in seconds)
    }

    // Struct to hold information about a user's staking
    struct StakingInfo {
        uint256 stakedAmount;  // The amount the user has staked
        uint256 earnedReward; // The reward accumulated for this stake
        uint256 releaseTime;  // The time when the stake can be withdrawn
        bool isWithdrawn;     // Whether the stake has been withdrawn or not
    }

    // Mappings to store contract state:
    mapping(uint8 => StakingTier) public stakingTiers; // Mapping of tier ID to its respective properties
    mapping(address => mapping(uint8 => StakingInfo)) public userStakes; // Mapping of user address to tier stakes
    mapping(address => bool) public isWhitelisted; // Mapping of whitelisted users
    mapping(address => uint256) public previousStakeTime; // The last time a user made a stake
    mapping(address => bool) public withdrawnStatus; // Whether a user has withdrawn their stake

    uint256 public stakingInterval = 1 days; // The cooldown period between stakes for a user

    // Events to log important contract actions
    event StakingTierModified(uint8 indexed tierId, uint256 rewardPercentage, uint256 lockDuration);
    event Staked(address indexed user, uint256 amount, uint8 tierId, uint256 reward, uint256 releaseTime);
    event Withdrawn(address indexed user, uint256 amount);
    event WhitelistStatusUpdated(address indexed user, bool status);

    // Custom errors to handle require statement failures
    error UnauthorizedAccess();
    error UserNotWhitelisted();
    error NoActiveStake(uint8 tierId);
    error StakingCooldownNotMet();
    error AlreadyWithdrawn();
    error InvalidTierId(uint8 tierId);
    error InvalidStakeAmount();
    error StakeStillLocked(uint256 releaseTime);

    // Modifier to allow only the contract owner to execute a function
    modifier onlyOwner() {
        if (msg.sender != owner) revert UnauthorizedAccess();
        _;
    }

    // Modifier to allow only whitelisted users to execute a function
    modifier whitelistedUser() {
        if (!isWhitelisted[msg.sender]) revert UserNotWhitelisted();
        _;
    }

    // Modifier to ensure the user has an active stake for the specified tier
    modifier activeStake(uint8 _tierId) {
        if (userStakes[msg.sender][_tierId].stakedAmount == 0) revert NoActiveStake(_tierId);
        _;
    }

    // Modifier to ensure the staking cooldown period has passed before allowing another stake
    modifier stakeAllowed() {
        if (block.timestamp < previousStakeTime[msg.sender] + stakingInterval) revert StakingCooldownNotMet();
        _;
    }

    // Modifier to ensure that the user has not already withdrawn their stake for the tier
    modifier withdrawalPermitted(uint8 _tierId) {
        if (withdrawnStatus[msg.sender]) revert AlreadyWithdrawn();
        _;
    }

    // Constructor to initialize the contract with the token address
    constructor(address _rewardToken) {
        owner = msg.sender; // Set the owner of the contract to the deployer
        rewardToken = IERC20(_rewardToken); // Initialize the reward token contract
        // Initialize default staking tiers with reward rates and lock durations
        stakingTiers[1] = StakingTier(500, 7 days);   // Tier 1: 5% reward, 7-day lock
        stakingTiers[2] = StakingTier(1000, 14 days); // Tier 2: 10% reward, 14-day lock
        stakingTiers[3] = StakingTier(1500, 30 days); // Tier 3: 15% reward, 30-day lock
    }

    // Function to update the reward percentage and lock duration for a specific tier
    function modifyStakingTier(uint8 _tierId, uint256 _rewardPercentage, uint256 _lockDuration) external onlyOwner {
        if (_tierId == 0) revert InvalidTierId(_tierId); // Reject tier ID 0 as invalid
        stakingTiers[_tierId] = StakingTier(_rewardPercentage, _lockDuration); // Update tier properties
        emit StakingTierModified(_tierId, _rewardPercentage, _lockDuration); // Emit an event for the update
    }

    // Function to whitelist or remove a user from the whitelist
    function updateWhitelistStatus(address _user, bool _status) external onlyOwner {
        isWhitelisted[_user] = _status; // Update the whitelist status for the user
        emit WhitelistStatusUpdated(_user, _status); // Emit an event for the change
    }

    // Function to stake tokens into the contract and start earning rewards
    function stake(uint8 _tierId, uint256 _amount) external payable whitelistedUser stakeAllowed {
        if (_amount == 0) revert InvalidStakeAmount(); // Reject zero stake amounts
        if (stakingTiers[_tierId].lockDuration == 0) revert InvalidTierId(_tierId); // Reject invalid tiers

        StakingInfo storage userStake = userStakes[msg.sender][_tierId]; // Get the user's stake details for the specified tier
        // Calculate the reward based on the tier's reward rate
        uint256 reward = (_amount * stakingTiers[_tierId].rewardPercentage) / 10000;
        rewardToken.transferFrom(msg.sender, address(this), _amount); // Transfer tokens from the user to the contract

        // Update the user's stake information
        userStakes[msg.sender][_tierId] = StakingInfo({
            stakedAmount: userStake.stakedAmount + _amount,
            earnedReward: userStake.earnedReward + reward,
            releaseTime: userStake.releaseTime + block.timestamp + stakingTiers[_tierId].lockDuration,
            isWithdrawn: false
        });

        previousStakeTime[msg.sender] = block.timestamp; // Update the last stake time

        emit Staked(msg.sender, _amount, _tierId, reward, block.timestamp + stakingTiers[_tierId].lockDuration); // Emit a staking event
    }

    // Function to withdraw the staked amount and its reward after the lock period
    function withdraw(uint8 _tierId) external whitelistedUser activeStake(_tierId) withdrawalPermitted(_tierId) {
        StakingInfo storage userStake = userStakes[msg.sender][_tierId]; // Get the user's stake for the tier
        if (block.timestamp <= userStake.releaseTime) revert StakeStillLocked(userStake.releaseTime); // Reject if the stake is still locked

        uint256 totalAmount = userStake.stakedAmount + userStake.earnedReward; // Calculate the total amount to be withdrawn
        withdrawnStatus[msg.sender] = true; // Mark the user as having withdrawn their stake

        // Reset the user's stake information
        userStakes[msg.sender][_tierId] = StakingInfo({
            stakedAmount: 0,
            earnedReward: 0,
            releaseTime: 0,
            isWithdrawn: true
        });

        rewardToken.transfer(msg.sender, totalAmount); // Transfer the total amount (principal + reward) to the user
        emit Withdrawn(msg.sender, totalAmount); // Emit a withdrawal event
    }

    // Function to get the details of a user's stake for a specific tier
    function getStakeDetails(address _user, uint8 _tierId) external view returns (uint256, uint256, uint256, bool) {
        StakingInfo memory userStake = userStakes[_user][_tierId]; // Get the stake details
        return (userStake.stakedAmount, userStake.earnedReward, userStake.releaseTime, userStake.isWithdrawn); // Return the details
    }

    // Fallback function to accept Ether sent to the contract
    receive() external payable {}
}
