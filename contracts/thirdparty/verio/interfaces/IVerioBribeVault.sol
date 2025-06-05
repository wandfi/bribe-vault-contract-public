// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "../../../interfaces/IVault.sol";
import "../interfaces/ipa/IComponentSelector.sol";

interface IVerioBribeVault is IVault {

  function componentSelector() external view returns (IComponentSelector);

}
