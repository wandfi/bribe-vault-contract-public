// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IStakePool} from "./IStakePool.sol";

interface IIPAssetStakePoolRegistry {
  /// @notice Event emitted when an IP asset stake pool is registered
  /// @param ipAsset Address of the IP asset
  /// @param stakePool Address of the stake pool
  event StakePoolRegisteredForIPAsset(address indexed ipAsset, address indexed stakePool);

  /// @notice Error emitted when an IP asset is not registered with the IP asset registry
  /// @param ipAsset Address of the IP asset
  /// @param ipAssetRegistry Address of the IP asset registry
  error IPAssetNotRegisteredWithIPAssetRegistry(address ipAsset, address ipAssetRegistry);

  /// @notice Error emitted when an IP asset stake pool is not registered
  /// @param ipAsset Address of the IP asset
  error StakePoolNotRegisteredForIPAsset(address ipAsset);

  /// @notice Get the stake pool for an IP asset
  /// @param _ipAsset Address of the IP asset
  /// @return Address of the stake pool
  function getStakePoolForIPAsset(address _ipAsset) external view returns (IStakePool);
}