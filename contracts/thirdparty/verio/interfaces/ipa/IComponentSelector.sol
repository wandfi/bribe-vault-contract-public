// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./IIPAssetStaking.sol";
import "./IIPAssetStakePoolRegistry.sol";

interface IComponentSelector {
  /// @notice Gets the IP asset staking contract
  /// @return Address of the IP asset staking contract
  function ipAssetStaking() external view returns (IIPAssetStaking);

  /// @notice Gets the lockup contract
  /// @return Address of the lockup contract
  function lockup() external view returns (ILockup);

  /// @notice Gets the IP asset stake pool registry contract
  /// @return Address of the IP asset stake pool registry contract
  function ipAssetStakePoolRegistry() external view returns (IIPAssetStakePoolRegistry);
}
