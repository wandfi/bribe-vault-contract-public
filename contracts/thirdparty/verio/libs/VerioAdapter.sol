// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../../libs/Constants.sol";
import "../interfaces/ipa/IComponentSelector.sol";
import "../interfaces/ipa/IIPAssetStakePoolRegistry.sol";
import "../interfaces/ipa/IIPAssetStaking.sol";
import "../interfaces/ipa/ILockup.sol";
import "../interfaces/ipa/IStakePool.sol";
import "../interfaces/IVerioBribeVault.sol";

library VerioAdapter {
  using EnumerableSet for EnumerableSet.AddressSet;
  using Math for uint256;

  function balanceOf(IVerioBribeVault self, address token) public view returns (uint256) {
    if (token == Constants.NATIVE_TOKEN) {
      return address(self).balance;
    }
    else {
      return IERC20(token).balanceOf(address(self));
    }
  }

  function selectIpAssetWithHighestApy(IVerioBribeVault self, address[] memory _ipAssets, ILockup.Type _lockupType) public view returns (address) {
    require(_ipAssets.length > 0, "VerioAdapter: No IP assets provided");

    uint256 highestApy = 0;
    address ipAssetWithHighestApy = address(0);
    for (uint256 i = 0; i < _ipAssets.length; i++) {
      require(ipAssetRegistered(self, _ipAssets[i]), "VerioAdapter: IP asset not registered");
      uint256 apy = calculateApy(self, _ipAssets[i], _lockupType);
      if (apy > highestApy) {
        highestApy = apy;
        ipAssetWithHighestApy = _ipAssets[i];
      }
    }
    require(ipAssetWithHighestApy != address(0), "VerioAdapter: No IP asset with highest APY found");
    return ipAssetWithHighestApy;
  }

  function calculateApy(IVerioBribeVault self, address _ipAsset, ILockup.Type _lockupType) public view returns (uint256) {
    uint256 SECONDS_PER_YEAR = 60 * 60 * 24 * 365;
    uint256 SCALE = 1e36; // Increased precision scaling factor
    uint256 DIVISOR = 25e17; // Equivalent to 2.5 in 1e18 fixed point

    IComponentSelector componentSelector = self.componentSelector();
    IIPAssetStaking ipAssetStaking = componentSelector.ipAssetStaking();

    uint256 lockupMultiplier = ILockup(componentSelector.lockup()).getLockupMultiplier(_lockupType);
    uint256 totalStake = ipAssetStaking.getTotalStakeWeightedInIPForIP(_ipAsset);
    IRewardPool.RewardPoolState[][] memory rewardPools = ipAssetStaking.getRewardPools(_ipAsset);
    uint256 cumulativeRewardsPerEpoch = 0;
    for (uint256 i = 0; i < rewardPools.length; i++) {
      for (uint256 j = 0; j < rewardPools[i].length; j++) {
        IRewardPool.RewardPoolState memory rewardPool = rewardPools[i][j];
        if (rewardPool.totalRewards > rewardPool.totalDistributedRewards) {
          cumulativeRewardsPerEpoch += rewardPool.rewardsPerEpoch;
        }
      }
    }

    uint256 apy = cumulativeRewardsPerEpoch.mulDiv(lockupMultiplier * SECONDS_PER_YEAR * SCALE * 100, totalStake * DIVISOR); 
    return apy;
  }

  function ipAssetRegistered(IVerioBribeVault self, address _ipAsset) public view returns (bool) {
    IComponentSelector componentSelector = self.componentSelector();
    IIPAssetStakePoolRegistry ipAssetStakePoolRegistry = componentSelector.ipAssetStakePoolRegistry();
    try ipAssetStakePoolRegistry.getStakePoolForIPAsset(_ipAsset) {
      return true;
    } catch {
      return false;
    }
  }

  function stake(IVerioBribeVault self, address _ipAsset, address _stakeTokenAddress, uint256 _amount, ILockup.Type _type) public {
    IComponentSelector componentSelector = self.componentSelector();
    IIPAssetStaking ipAssetStaking = componentSelector.ipAssetStaking();
    ipAssetStaking.stake(_ipAsset, _stakeTokenAddress, _amount, _type);
  }

  function unstake(IVerioBribeVault self, address _ipAsset, address _stakeTokenAddress, uint256 _amount, ILockup.Type _type) public {
    IComponentSelector componentSelector = self.componentSelector();
    IIPAssetStaking ipAssetStaking = componentSelector.ipAssetStaking();
    ipAssetStaking.unstake(_ipAsset, _stakeTokenAddress, _amount, _type);
  }

  function unstakeAll(IVerioBribeVault self, address _ipAsset, address _stakeTokenAddress, ILockup.Type _type) public {
    IComponentSelector componentSelector = self.componentSelector();
    IIPAssetStaking ipAssetStaking = componentSelector.ipAssetStaking();
    uint256 totalAmount = totalStakeAmount(self, _ipAsset, _stakeTokenAddress, _type);
    if (totalAmount > 0) {
      ipAssetStaking.unstake(_ipAsset, _stakeTokenAddress, totalAmount, _type);
    }
  }

  /**
   * 
   * @dev Unstake from multiple pools until the desired amount is unstaked.
   * Note, there are unstake fees, so the amount unstaked may be less than the desired amount.
   */
  function unstakeFromMultiplePools(IVerioBribeVault self, address[] memory _ipAssets, address _stakeTokenAddress, uint256 _amount, ILockup.Type _type) public {
    require(_ipAssets.length > 0, "VerioAdapter: No IP assets provided");

    uint256 remainingAmount = _amount;
    for (uint256 i = 0; i < _ipAssets.length; i++) {
      address ipAsset = _ipAssets[i];
      uint256 stakeAmount = totalStakeAmount(self, ipAsset, _stakeTokenAddress, _type);
      uint256 amountToUnstake = Math.min(stakeAmount, remainingAmount);
      remainingAmount -= amountToUnstake;

      if (amountToUnstake > 0) {
        unstake(self, ipAsset, _stakeTokenAddress, amountToUnstake, _type);
      }

      if (remainingAmount == 0) {
        break;
      }
    }
    require(remainingAmount == 0, "VerioAdapter: Not enough staked amount to unstake");
  }

  function totalStakeAmount(IVerioBribeVault self, address _ipAsset, address _stakeTokenAddress, ILockup.Type _type) public view returns (uint256) {
    IComponentSelector componentSelector = self.componentSelector();
    IIPAssetStaking ipAssetStaking = componentSelector.ipAssetStaking();
    IStakePool.UserStakeAmountDetail[][] memory userStakeAmountDetails = ipAssetStaking.getUserStakeAmountForIP(_ipAsset, address(self));

    uint256 totalAmount = 0;
    for (uint256 i = 0; i < userStakeAmountDetails.length; i++) {
      for (uint256 j = 0; j < userStakeAmountDetails[i].length; j++) {
        if (userStakeAmountDetails[i][j].stakeTokenAddress == _stakeTokenAddress && userStakeAmountDetails[i][j].lockup == _type) {
          totalAmount += userStakeAmountDetails[i][j].amount;
        }
      }
    }
    return totalAmount;
  }

  function claimRewards(IVerioBribeVault self, address _ipAsset) public {
    IComponentSelector componentSelector = self.componentSelector();
    IIPAssetStaking ipAssetStaking = componentSelector.ipAssetStaking();
    ipAssetStaking.claimRewards(_ipAsset);
  }

  /**
   * @dev
   * 1. Reward tokens could be duplicated, like with different distribution types or rewards per epoch. 
   * 2. The reward token could be NATIVE, in which case we should use our own native token address.
   */
  function rewardTokens(IVerioBribeVault self, address _ipAsset) public view returns (address[] memory) {
    IComponentSelector componentSelector = self.componentSelector();
    IIPAssetStaking ipAssetStaking = componentSelector.ipAssetStaking();
    IRewardPool.RewardPoolState[][] memory rewardPools = ipAssetStaking.getRewardPools(_ipAsset);

    // Count total reward tokens across all pools
    uint256 totalTokens = 0;
    for (uint256 i = 0; i < rewardPools.length; i++) {
      totalTokens += rewardPools[i].length;
    }

    address[] memory _rewardTokens = new address[](totalTokens);
    uint256 currentIndex = 0;
    
    // Add all reward tokens from all pools
    for (uint256 i = 0; i < rewardPools.length; i++) {
      for (uint256 j = 0; j < rewardPools[i].length; j++) {
        if (rewardPools[i][j].rewardTokenType == IRewardPool.RewardTokenType.NATIVE) {
          _rewardTokens[currentIndex] = Constants.NATIVE_TOKEN;
        } else {
          _rewardTokens[currentIndex] = rewardPools[i][j].rewardToken;
        }
        currentIndex++;
      }
    }

    return _rewardTokens;
  }

  function mergeRewardTokens(IVerioBribeVault self, address[] memory _ipAssets, EnumerableSet.AddressSet storage uniqueSet) public returns (address[] memory) {
    while (uniqueSet.length() > 0) {
      uniqueSet.remove(uniqueSet.at(0));
    }

    for (uint256 i = 0; i < _ipAssets.length; i++) {
      address[] memory tokens = rewardTokens(self, _ipAssets[i]);
      for (uint256 j = 0; j < tokens.length; j++) {
        uniqueSet.add(tokens[j]);
      }
    }

    return uniqueSet.values();
  }

}
