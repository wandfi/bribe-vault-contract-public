// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/ipa/IComponentSelector.sol";
import "./interfaces/ipa/ILockup.sol";
import "./interfaces/IVerioBribeVault.sol";
import "./interfaces/IWIP.sol";
import "./libs/VerioAdapter.sol";

import "../../vaults/Vault.sol";

contract VerioBribeVault is IVerioBribeVault, Vault {
  using EnumerableSet for EnumerableSet.AddressSet;
  using VerioAdapter for IVerioBribeVault;
  using Math for uint256;

  IComponentSelector public immutable componentSelector;
  IERC20 public immutable vIP;
  IWIP public immutable wIP;

  EnumerableSet.AddressSet internal _ipAssets;
  EnumerableSet.AddressSet internal _tmpRewardTokensSet;

  uint256 public maxIpAssets = 3;
  uint256 public C; 

  constructor(
    address _protocol,
    address _settings,
    address _redeemPoolFactory,
    address _bribesPoolFactory,
    address _componentSelector,
    address _wIP,
    address _assetToken_,
    string memory _pTokenName, string memory _pTokensymbol
  ) Vault(_protocol, _settings, _redeemPoolFactory, _bribesPoolFactory, _assetToken_, _pTokenName, _pTokensymbol) {
    require(_componentSelector != address(0) && _wIP != address(0), "Zero address detected");
    componentSelector = IComponentSelector(_componentSelector);

    vIP = IERC20(_assetToken_);
    wIP = IWIP(_wIP);
    C = 1e4 * (10 ** IERC20Metadata(address(vIP)).decimals());
  }

  /* ================= VIEWS ================ */

  function redeemAssetToken() public view override returns (address) {
    return address(vIP);
  }

  function ipAssets() public view returns (address[] memory) {
    return _ipAssets.values();
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function _assetBalance() internal view override returns (uint256) {
    uint256 totalBalance = vIP.balanceOf(address(this));
    for (uint256 i = 0; i < _ipAssets.length(); i++) {
      totalBalance += IVerioBribeVault(this).totalStakeAmount(_ipAssets.at(i), address(vIP), ILockup.Type.LONG);
    }
    return totalBalance;
  }

  function _depositToUnderlyingVault(uint256) internal override {
    // If no IP assets added yet, just keep the asset in the vault
    if (_ipAssets.length() == 0 || C == 0) {
      return;
    }

    uint256 balance = vIP.balanceOf(address(this));
    uint256 depositAmount = Math.min(balance, C);

    address ipAssetWithHighestApy = IVerioBribeVault(this).selectIpAssetWithHighestApy(ipAssets(), ILockup.Type.LONG);
    vIP.approve(address(componentSelector.ipAssetStaking()), depositAmount);
    IVerioBribeVault(this).stake(ipAssetWithHighestApy, address(vIP), depositAmount, ILockup.Type.LONG);
  }

  function _settleRedeemPool(IRedeemPool redeemPool) internal override {
    uint256 amount = redeemPool.totalRedeemingBalance();
    if (amount > 0) {
      IPToken(pToken).burn(address(redeemPool), amount);

      uint256 balance = vIP.balanceOf(address(this));
      if (balance >= amount) {
        TokensTransfer.transferTokens(address(vIP), address(this), address(redeemPool), amount);
        redeemPool.notifySettlement(amount);
      }
      else {
        uint256 unstakeAmount = amount - balance;
        IVerioBribeVault(this).unstakeFromMultiplePools(ipAssets(), address(vIP), unstakeAmount, ILockup.Type.LONG);
        uint256 updatedBalance = vIP.balanceOf(address(this));
        TokensTransfer.transferTokens(address(vIP), address(this), address(redeemPool), updatedBalance);
        redeemPool.notifySettlement(updatedBalance);
      }
    }
  }

  function _doUpdateStakingBribes(IBribesPool stakingBribesPool) internal override {

    address[] memory rewardTokens = IVerioBribeVault(this).mergeRewardTokens(ipAssets(), _tmpRewardTokensSet);

    uint256[] memory prevBalances = new uint256[](rewardTokens.length);
    for (uint256 i = 0; i < rewardTokens.length; i++) {
      prevBalances[i] = IVerioBribeVault(this).balanceOf(rewardTokens[i]);
    }

    for (uint256 i = 0; i < _ipAssets.length(); i++) {
      address ipAsset = _ipAssets.at(i);
      IVerioBribeVault(this).claimRewards(ipAsset);
    }

    for (uint256 i = 0; i < rewardTokens.length; i++) {
      address bribeToken = rewardTokens[i];
      uint256 bribeAmount = IVerioBribeVault(this).balanceOf(bribeToken) - prevBalances[i];

      if (bribeAmount > 0) {
        if (bribeToken == Constants.NATIVE_TOKEN) {
          wIP.deposit{value: bribeAmount}();
          bribeToken = address(wIP);
        }

        IERC20(bribeToken).approve(address(stakingBribesPool), bribeAmount);
        stakingBribesPool.addBribes(bribeToken, bribeAmount);
      }
    }
  }

  function _onVaultClose() internal override {
    for (uint256 i = 0; i < _ipAssets.length(); i++) {
      IVerioBribeVault(this).unstakeAll(_ipAssets.at(i), address(vIP), ILockup.Type.LONG);
    }
  }

  function _redeemOnClose(uint256 ptAmount) internal override {
    uint256 ptTotalSupply = IERC20(pToken).totalSupply();
    uint256 totalAssets = vIP.balanceOf(address(this));
    uint256 vipAmount = ptAmount.mulDiv(totalAssets, ptTotalSupply);

    IPToken(pToken).burn(_msgSender(), ptAmount);
    if (vipAmount > 0) {
      TokensTransfer.transferTokens(address(vIP), address(this), _msgSender(), vipAmount);
    }
  }

  /* ========== RESTRICTED FUNCTIONS ========== */

  function addIpAsset(address ipAsset) external nonReentrant onlyOwner {
    require(ipAsset != address(0), "Zero address detected");
    require(!_ipAssets.contains(ipAsset), "IP asset already added");
    require(_ipAssets.length() < maxIpAssets, "Max IP assets reached");
    require(IVerioBribeVault(this).ipAssetRegistered(ipAsset), "IP asset not registered");

    _ipAssets.add(ipAsset);
    emit AddIpAsset(ipAsset);
  }

  function removeIpAsset(address ipAsset) external nonReentrant onlyOwner {
    require(ipAsset != address(0), "Zero address detected");
    require(_ipAssets.contains(ipAsset), "IP asset not found");

    // for simplicity, we claim rewards from all IP asset pools before removing the IP asset
    _updateStakingBribes();
    IVerioBribeVault(this).unstakeAll(ipAsset, address(vIP), ILockup.Type.LONG);

    _ipAssets.remove(ipAsset);
    emit RemoveIpAsset(ipAsset);
  }

  function updateMaxIpAssets(uint256 newMaxIpAssets) external nonReentrant onlyOwner {
    require(newMaxIpAssets > 0 && newMaxIpAssets != maxIpAssets, "Invalid max IP assets");
    uint256 previousMaxIpAssets = maxIpAssets;
    maxIpAssets = newMaxIpAssets;
    emit UpdateMaxIpAssets(previousMaxIpAssets, newMaxIpAssets);
  }

  function updateC(uint256 newC) external nonReentrant onlyOwner {
    require(newC >= 0 && newC != C, "Invalid C");
    uint256 previousC = C;
    C = newC;
    emit UpdateC(previousC, newC);
  }


  /* =============== EVENTS ============= */

  event AddIpAsset(address indexed ipAsset);
  event RemoveIpAsset(address indexed ipAsset);

  event UpdateMaxIpAssets(uint256 previousMaxIpAssets, uint256 newMaxIpAssets);
  event UpdateC(uint256 previousC, uint256 newC);

}