// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./ILockup.sol";

interface IStakePool {

  /// @notice State for the user stake amount detail
  /// @param stakeTokenAddress Address of the stake token
  /// @param amount Amount of stake
  /// @param lockup Type of lockup
  /// @param lastStakeTimestamp Last stake timestamp
  struct UserStakeAmountDetail {
    address stakeTokenAddress;
    uint256 amount;
    ILockup.Type lockup;
    uint256 lastStakeTimestamp;
  }

}