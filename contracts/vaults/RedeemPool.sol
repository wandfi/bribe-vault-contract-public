// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../libs/Constants.sol";
import "../libs/TokensTransfer.sol";
import "../interfaces/IProtocolSettings.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IProtocol.sol";

contract RedeemPool is Context, Pausable, ReentrancyGuard {
  using Math for uint256;
  using SafeERC20 for IERC20;

  /* ========== STATE VARIABLES ========== */

  IVault internal immutable _vault;
  bool internal _settled;

  address internal immutable _redeemingPToken;  // $piBGT
  address internal immutable _assetToken;  // $iBGT

  uint256 internal _totalRedeemingShares;  // $piBGT shares
  mapping(address => uint256) internal _userRedeemingShares;

  uint256 internal _assetAmountPerRedeemingShare;   // $iBGT amount
  mapping(address => uint256) internal _userAssetAmountPerRedeemingSharePaid;
  mapping(address => uint256) internal _userAssetAmounts;

  /* ========== CONSTRUCTOR ========== */

  constructor(
    address _vault_
  ) {
    _vault = IVault(_vault_);

    _redeemingPToken = _vault.pToken();
    _assetToken = _vault.redeemAssetToken();
  }

  /* ========== VIEWS ========== */

  function vault() public view returns (address) {
    return address(_vault);
  }

  function redeemingToken() public view returns (address) {
    return _redeemingPToken;
  }

  function assetToken() public view returns (address) {
    return _assetToken;
  }

  function settled() public view returns (bool) {
    return _settled;
  }

  function totalRedeemingShares() external view returns (uint256) {
    return _totalRedeemingShares;
  }

  function userRedeemingShares(address account) external view returns (uint256) {
    return _userRedeemingShares[account];
  }

  // $piBGT
  function totalRedeemingBalance() public view onlyBeforeSettlement returns (uint256) {
    return IERC20(_redeemingPToken).balanceOf(address(this));
  }

  // $piBGT
  function userRedeemingBalance(address account) external view onlyBeforeSettlement returns (uint256) {
    return _convertToAssets(_userRedeemingShares[account], Math.Rounding.Floor);
  }

  // $iBGT
  function earnedAssetAmount(address account) public view returns (uint256) {
    return _userRedeemingShares[account].mulDiv(
      _assetAmountPerRedeemingShare - _userAssetAmountPerRedeemingSharePaid[account], 1e28, Math.Rounding.Floor
    ) + _userAssetAmounts[account];
  }

  function getRedeemingSharesByBalance(uint256 stakingBalance) external virtual view onlyBeforeSettlement returns (uint256) {
    return _convertToShares(stakingBalance, Math.Rounding.Floor);
  }

  function getRedeemingBalanceByShares(uint256 stakingShares) external virtual view onlyBeforeSettlement returns (uint256) {
    return _convertToAssets(stakingShares, Math.Rounding.Floor);
  }

  // https://docs.openzeppelin.com/contracts/5.x/erc4626
  // https://github.com/boringcrypto/YieldBox/blob/master/contracts/YieldBoxRebase.sol
  function decimalsOffset() public view virtual returns (uint8) {
    return 8;
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  function redeem(uint256 amount) external nonReentrant whenNotPaused onlyBeforeSettlement updateAssetAmount(_msgSender()) {
    require(amount > 0, "Cannot redeem 0");
    require(IERC20(_redeemingPToken).balanceOf(_msgSender()) >= amount, "Insufficient balance");

    uint256 sharesAmount = _convertToShares(amount, Math.Rounding.Floor);
    _totalRedeemingShares = _totalRedeemingShares + sharesAmount;
    _userRedeemingShares[_msgSender()] = _userRedeemingShares[_msgSender()] + sharesAmount;

    TokensTransfer.transferTokens(_redeemingPToken, _msgSender(), address(this), amount);
    emit Redeem(_msgSender(), amount);
  }

  function withdrawRedeem(uint256 amount) public nonReentrant whenNotPaused onlyBeforeSettlement updateAssetAmount(_msgSender()) {
    require(amount > 0, "Cannot withdraw 0");
    require(amount <= _convertToAssets(_userRedeemingShares[_msgSender()], Math.Rounding.Floor), "Insufficient redeeming balance");

    uint256 sharesAmount = _convertToShares(amount, Math.Rounding.Ceil);
    _totalRedeemingShares = _totalRedeemingShares - sharesAmount;
    _userRedeemingShares[_msgSender()] = _userRedeemingShares[_msgSender()] - sharesAmount;

    TokensTransfer.transferTokens(_redeemingPToken, address(this), _msgSender(), amount);
    emit WithdrawRedeem(_msgSender(), amount);
  }

  // $iBGT
  function claimAssetToken() external {
    _claimAssetToken(_msgSender());
  }

  function claimAssetTokenFor(address account) external onlyVault {
    _claimAssetToken(account);
  }

  function exit() external {
    if (!_settled) {
      withdrawRedeem(_convertToAssets(_userRedeemingShares[_msgSender()], Math.Rounding.Floor));
    }
    else {
      _claimAssetToken(_msgSender());
    }
  }

  /* ========== RESTRICTED FUNCTIONS ========== */

  function pause() external nonReentrant onlyVault {
    _pause();
  }

  function unpause() external nonReentrant onlyVault {
    _unpause();
  }

  function notifySettlement(uint256 assetAmount) external nonReentrant onlyBeforeSettlement onlyVault {
    _settled = true;
    if (assetAmount > 0) {
      require(_totalRedeemingShares > 0, "No redeems");
      _assetAmountPerRedeemingShare = _assetAmountPerRedeemingShare + (
        assetAmount.mulDiv(1e28, _totalRedeemingShares)
      );
    }
    emit Settlement(assetAmount);
  }

  /* ================= INTERNAL Functions ================ */


  function _claimAssetToken(address account) internal nonReentrant onlyAfterSettlement updateAssetAmount(account) {
    uint256 amount = _userAssetAmounts[account];
    if (amount > 0) {
      _userAssetAmounts[account] = 0;

      IProtocolSettings settings = IProtocolSettings(_vault.settings());
      uint256 fees = amount.mulDiv(
        settings.vaultParamValue(address(_vault), "f1"),
        10 ** settings.decimals()
      );
      uint256 netAmount = amount - fees;

      if (netAmount > 0) {
        TokensTransfer.transferTokens(_assetToken, address(this), account, netAmount);
      }
      if (fees > 0) {
        TokensTransfer.transferTokens(_assetToken, address(this), settings.treasury(), fees);
      }
      
      emit AssetTokenClaimed(account, amount, netAmount, fees);
    }
  }

  function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
    return assets.mulDiv(
      _totalRedeemingShares + 10 ** decimalsOffset(), 
      totalRedeemingBalance() + 1, 
      rounding
    );
  }

  function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
    return shares.mulDiv(
      totalRedeemingBalance() + 1,
      _totalRedeemingShares + 10 ** decimalsOffset(),
      rounding
    );
  }

  /* ========== MODIFIERS ========== */

  modifier onlyBeforeSettlement() {
    require(!_settled, "Already settled");
    _;
  }

  modifier onlyAfterSettlement() {
    require(_settled, "Not settled");
    _;
  }

  modifier onlyVault() {
    require(_msgSender() == address(_vault), "Caller is not Vault");
    _;
  }

  modifier updateAssetAmount(address account) {
    if (account != address(0)) {
      _userAssetAmounts[account] = earnedAssetAmount(account);
      _userAssetAmountPerRedeemingSharePaid[account] = _assetAmountPerRedeemingShare;
    }
    _;
  }

  /* ========== EVENTS ========== */

  event Redeem(address indexed user, uint256 amount);
  event WithdrawRedeem(address indexed user, uint256 amount);

  event AssetTokenClaimed(address indexed user, uint256 amount, uint256 netAmount, uint256 fees);
  event Settlement(uint256 assetAmount);
}