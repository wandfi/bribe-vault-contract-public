// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../thirdparty/infrared/interfaces/IInfraredStakingPool.sol";
import "../settings/ProtocolOwner.sol";
import "../libs/TokensTransfer.sol";

contract MockInfraredStakingPool is ReentrancyGuard, ProtocolOwner, IInfraredStakingPool {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  /* ========== STATE VARIABLES ========== */

  struct Reward {
    uint256 rewardsDuration;
    uint256 periodFinish;
    uint256 rewardRate;
    uint256 lastUpdateTime;
    uint256 rewardPerTokenStored;
  }
  address public stakingToken;
  mapping(address => Reward) public rewardData;
  EnumerableSet.AddressSet internal rewardTokens;

  // user -> reward token -> amount
  mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
  mapping(address => mapping(address => uint256)) public rewards;

  uint256 private _totalSupply;
  mapping(address => uint256) private _balances;

  /* ========== CONSTRUCTOR ========== */

  constructor(
    address _protocol,
    address _stakingToken
  ) ProtocolOwner(_protocol) {
    // could be native token
    stakingToken = _stakingToken;
  }

  /* ========== VIEWS ========== */

  function getAllRewardTokens() external view returns (address[] memory) {
    return rewardTokens.values();
  }

  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) external view returns (uint256) {
    return _balances[account];
  }

  function lastTimeRewardApplicable(address _rewardsToken) public view returns (uint256) {
    return Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
  }

  function rewardPerToken(address _rewardsToken) public view returns (uint256) {
    if (_totalSupply == 0) {
      return rewardData[_rewardsToken].rewardPerTokenStored;
    }
    return
      rewardData[_rewardsToken].rewardPerTokenStored + (
        (lastTimeRewardApplicable(_rewardsToken) - rewardData[_rewardsToken].lastUpdateTime) * rewardData[_rewardsToken].rewardRate * 1e18 / _totalSupply
      );
  }

  function earned(address account, address _rewardsToken) public view returns (uint256) {
    return _balances[account] * (
      rewardPerToken(_rewardsToken) - userRewardPerTokenPaid[account][_rewardsToken]
    ) / 1e18 + rewards[account][_rewardsToken];
  }

  function getRewardForDuration(address _rewardsToken) external view returns (uint256) {
    return rewardData[_rewardsToken].rewardRate * (rewardData[_rewardsToken].rewardsDuration);
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
    require(amount > 0, "Cannot stake 0");
    _totalSupply = _totalSupply + amount;
    _balances[msg.sender] = _balances[msg.sender] + amount;
    TokensTransfer.transferTokens(stakingToken, msg.sender, address(this), amount);
    emit Staked(msg.sender, amount);
  }

  function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
    require(amount > 0, "Cannot withdraw 0");
    _totalSupply = _totalSupply - amount;
    _balances[msg.sender] = _balances[msg.sender] - amount;
    TokensTransfer.transferTokens(stakingToken, address(this), msg.sender, amount);
    emit Withdrawn(msg.sender, amount);
  }

  function getReward() public nonReentrant updateReward(msg.sender) {

    for (uint i; i < rewardTokens.length(); i++) {
      address _rewardsToken = rewardTokens.at(i);
      uint256 reward = rewards[msg.sender][_rewardsToken];
      if (reward > 0) {
        rewards[msg.sender][_rewardsToken] = 0;
        TokensTransfer.transferTokens(_rewardsToken, address(this), msg.sender, reward);
        emit RewardPaid(msg.sender, _rewardsToken, reward);
      }
  }
  }

  function exit() external {
    withdraw(_balances[msg.sender]);
    getReward();
  }

  /* ========== RESTRICTED FUNCTIONS ========== */

  function addReward(address _rewardsToken, uint256 reward, uint256 rewardsDuration) external payable onlyOwner updateReward(address(0)) {
      if (!rewardTokens.contains(_rewardsToken)) {
      rewardTokens.add(_rewardsToken);
      emit RewardsTokenAdded(_rewardsToken);
    }
    rewardData[_rewardsToken].rewardsDuration = rewardsDuration;

    TokensTransfer.transferTokens(_rewardsToken, msg.sender, address(this), reward);

    if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
      rewardData[_rewardsToken].rewardRate = reward / (rewardData[_rewardsToken].rewardsDuration);
    } else {
      uint256 remaining = rewardData[_rewardsToken].periodFinish - (block.timestamp);
      uint256 leftover = remaining * (rewardData[_rewardsToken].rewardRate);
      rewardData[_rewardsToken].rewardRate = (reward + leftover) / (rewardData[_rewardsToken].rewardsDuration);
    }

    rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
    rewardData[_rewardsToken].periodFinish = block.timestamp + (rewardData[_rewardsToken].rewardsDuration);
    emit RewardAdded(reward);
  }

  // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
  function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
    require(tokenAddress != address(stakingToken), "Cannot withdraw staking token");
    require(rewardData[tokenAddress].lastUpdateTime == 0, "Cannot withdraw reward token");
    TokensTransfer.transferTokens(tokenAddress, address(this), owner(), tokenAmount);
    emit Recovered(tokenAddress, tokenAmount);
  }

  /* ========== MODIFIERS ========== */

  modifier updateReward(address account) {
    for (uint i; i < rewardTokens.length(); i++) {
      address token = rewardTokens.at(i);
      rewardData[token].rewardPerTokenStored = rewardPerToken(token);
      rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
      if (account != address(0)) {
        rewards[account][token] = earned(account, token);
        userRewardPerTokenPaid[account][token] = rewardData[token].rewardPerTokenStored;
      }
    }
    _;
  }

  /* ========== EVENTS ========== */

  event RewardsTokenAdded(address indexed rewardsToken);
  event RewardAdded(uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event RewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);
  event Recovered(address token, uint256 amount);
}