// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWIP is IERC20 {
  function deposit() external payable;
  
  function withdraw(uint value) external;
}