// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../thirdparty/verio/interfaces/ipa/IIPAssetStaking.sol";
import "../thirdparty/verio/interfaces/ipa/IRewardPool.sol";
import "../thirdparty/verio/interfaces/ipa/IComponentSelector.sol";
import "../thirdparty/verio/interfaces/ipa/ILockup.sol";

contract VerioQuery {
  using Strings for uint256;

  IComponentSelector componentSelector;
  IIPAssetStaking ipAssetStaking;

  uint256 private constant SECONDS_PER_YEAR = 60 * 60 * 24 * 365;
  uint256 private constant SCALE = 1e36; // Increased precision scaling factor
  uint256 private constant DIVISOR = 25e17; // Equivalent to 2.5 in 1e18 fixed point

  constructor(address _componentSelector) {
    componentSelector = IComponentSelector(_componentSelector);
    ipAssetStaking = IIPAssetStaking(componentSelector.ipAssetStaking());
  }

  function calculateAPY(address _ipAsset, ILockup.Type _lockupType) external view {
    console.log("Calculating APY for IP asset:", _ipAsset);
    console.log("Lockup type:", uint8(_lockupType));
    uint256 lockupMultiplier = ILockup(componentSelector.lockup()).getLockupMultiplier(_lockupType);
    console.log("Lockup multiplier:", lockupMultiplier);
    uint256 totalStake = ipAssetStaking.getTotalStakeWeightedInIPForIP(_ipAsset);
    console.log("Total stake:", totalStake);
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
    console.log("Cumulative rewards per epoch:", cumulativeRewardsPerEpoch);
    
    uint256 apy = (cumulativeRewardsPerEpoch * SECONDS_PER_YEAR * SCALE * 100) / (totalStake * DIVISOR); 
    console.log("Raw APY:", apy);

    uint256 apyWithLockup = apy * lockupMultiplier;
    console.log("APY with lockup:", apyWithLockup);
        
    // Format APY as string with 2 decimal places
    string memory apyString = string(abi.encodePacked(
      (apyWithLockup / 1e18).toString(),  // Integer part
      ".",
      _padZeros((apyWithLockup % 1e18 / 1e16).toString()), // Decimal part
      "%"
    ));
    console.log("APY:", apyString);
  }

  function _padZeros(string memory s) internal pure returns (string memory) {
    bytes memory b = bytes(s);
    if (b.length == 0) return "00";
    if (b.length == 1) return string(abi.encodePacked("0", s));
    return s;
  }
}