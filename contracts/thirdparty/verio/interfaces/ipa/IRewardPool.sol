// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IRewardPool {
  /// @notice Enum for the reward token type
  enum RewardTokenType {
    ERC20,
    NATIVE
  }

  /// @notice Enum for the distribution type
  enum DistributionType {
    CONTINUOUS,
    STATIC
  }

  /// @notice State for the reward pool
  /// @param rewardToken Address of the reward token
  /// @param rewardTokenType Type of reward token
  /// @param distributionType Distribution type
  /// @param rewardsPerEpoch Rewards per epoch
  /// @param rewardPerToken Reward per token
  /// @param totalRewards Total rewards
  /// @param totalDistributedRewards Total distributed rewards
  /// @param lastEpochBlock Last epoch block
  struct RewardPoolState {
    address rewardToken;
    RewardTokenType rewardTokenType;
    DistributionType distributionType;
    uint256 rewardsPerEpoch;
    uint256 rewardPerToken;
    uint256 totalRewards;
    uint256 totalDistributedRewards;
    uint256 lastEpochBlock;
  }

  
}