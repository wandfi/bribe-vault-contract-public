// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IProtocol {

  function protocolOwner() external view returns (address);

  function isVault(address vaultAddress) external view returns (bool);

  function isVaultAsset(address assetToken) external view returns (bool);
}