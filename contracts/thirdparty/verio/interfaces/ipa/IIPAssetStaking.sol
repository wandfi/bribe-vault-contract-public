// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./IRewardPool.sol";
import "./IStakePool.sol";

interface IIPAssetStaking {

  /// @notice Stakes tokens for an IP asset
  /// @param _ipAsset Address of the IP asset
  /// @param _stakeTokenAddress Address of the stake token
  /// @param _amount Amount of tokens to stake
  /// @param _type Type of lockup
  function stake(address _ipAsset, address _stakeTokenAddress, uint256 _amount, ILockup.Type _type)
    external
    payable;

  /// @notice Stakes tokens for an IP asset on behalf of another user
  /// @param _ipAsset Address of the IP asset
  /// @param _stakeTokenAddress Address of the stake token
  /// @param _amount Amount of tokens to stake
  /// @param _type Type of lockup
  /// @param _user Address of the user
  function stakeOnBehalf(
    address _ipAsset,
    address _stakeTokenAddress,
    uint256 _amount,
    ILockup.Type _type,
    address _user
  ) external payable;

  /// @notice Unstakes tokens for an IP asset
  /// @param _ipAsset Address of the IP asset
  /// @param _stakeTokenAddress Address of the stake token
  /// @param _amount Amount of tokens to unstake
  /// @param _type Type of lockup
  function unstake(address _ipAsset, address _stakeTokenAddress, uint256 _amount, ILockup.Type _type) external;

  /// @notice Unstakes tokens for an IP asset on behalf of another user
  /// @param _ipAsset Address of the IP asset
  /// @param _stakeTokenAddress Address of the stake token
  /// @param _amount Amount of tokens to unstake
  /// @param _type Type of lockup
  /// @param _user Address of the user
  function unstakeOnBehalf(
    address _ipAsset,
    address _stakeTokenAddress,
    uint256 _amount,
    ILockup.Type _type,
    address _user
  ) external;

  /// @notice Gets the total stake weighted by lockup periods for an IP asset.
  /// @return Total stake weighted by lockup peirods for an IP asset.
  function getTotalStakeWeightedInIPForIP(address _ipAsset) external view returns (uint256);

  /// @notice Gets the reward pools for an incentive pool creator
  /// @param _ipAsset Address of the IP asset
  /// @return Reward pools for the incentive pool creator
  function getRewardPools(address _ipAsset) external view returns (IRewardPool.RewardPoolState[][] memory);

  /// @notice Claims rewards for an IP asset
  /// @param _ipAsset Address of the IP asset
  function claimRewards(address _ipAsset) external;

  /// @notice Claims rewards for an IP asset on behalf of another user
  /// @param _ipAsset Address of the IP asset
  /// @param _user Address of the user
  function claimRewardsOnBehalf(address _ipAsset, address _user) external;

  /// @notice Gets the user's stake amount for an IP asset
  /// @param _ipAsset Address of the IP asset
  /// @param _user Address of the user
  /// @return Stake amount for the user
  function getUserStakeAmountForIP(address _ipAsset, address _user)
    external
    view
    returns (IStakePool.UserStakeAmountDetail[][] memory);


}
