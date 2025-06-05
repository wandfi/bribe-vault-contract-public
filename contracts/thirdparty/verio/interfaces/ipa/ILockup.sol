// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface ILockup {
  
  /// @notice Enum for the lockup type
  enum Type {
    INSTANT, // 0
    SHORT, // 1
    LONG // 2
  }

  /// @notice Struct for the lockup
  /// @param lockupType Type of lockup
  /// @param multiplier Multiplier for the lockup
  /// @param period Period for the lockup
  struct Lockup {
    Type lockupType;
    uint256 multiplier;
    uint256 period;
  }

  /// @notice Gets the lockup multiplier
  /// @param _lockupType Type of lockup
  /// @return Multiplier for the lockup
  function getLockupMultiplier(Type _lockupType) external view returns (uint256);
}