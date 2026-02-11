// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FeeVaultPodStorage} from "./FeeVaultPodStorage.sol";
import "../../interfaces/event/IAdminFeeVault.sol";

contract FeeVaultPod is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuard, FeeVaultPodStorage {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant MAX_ADMIN_FEE_RATE = 5000; // 50%
    uint256 public constant FEE_DENOMINATOR = 10000; // 100%

    // Errors
    error OnlyFeeVaultManager();
    error OnlyOwnerOrWithdrawManager();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidFeeRate();
    error InsufficientBalance();
    error TransferFailed();

    // Modifiers
    modifier onlyFeeVaultManager() {
        if (msg.sender != feeVaultManager) revert OnlyFeeVaultManager();
        _;
    }

    modifier onlyOwnerOrWithdrawManager() {
        if (msg.sender != owner() && msg.sender != withdrawManager) revert OnlyOwnerOrWithdrawManager();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the FeeVaultPod
     * @param _owner The owner address
     * @param _feeVaultManager The FeeVaultManager address
     * @param _withdrawManager The withdraw manager address
     * @param _adminFeeVault The AdminFeeVault address
     * @param _adminFeeRate The admin fee rate (basis points)
     */
    function initialize(
        address _owner,
        address _feeVaultManager,
        address _withdrawManager,
        address _adminFeeVault,
        uint256 _adminFeeRate
    ) external initializer {
        if (_owner == address(0) || _feeVaultManager == address(0) || _adminFeeVault == address(0)) {
            revert InvalidAddress();
        }
        if (_adminFeeRate > MAX_ADMIN_FEE_RATE) revert InvalidFeeRate();

        __Ownable_init(_owner);
        __Pausable_init();

        feeVaultManager = _feeVaultManager;
        withdrawManager = _withdrawManager;
        adminFeeVault = _adminFeeVault;
        adminFeeRate = _adminFeeRate;
    }

    /**
     * @notice Receive fee from other contracts
     * @param token The token address (ETHAddress for native ETH)
     * @param amount The total amount
     * @param feeType The fee type
     * @param feeAmount The fee amount
     */
    function receiveFee(address token, uint256 amount, uint8 feeType, uint256 feeAmount)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        if (amount == 0 || feeAmount == 0) revert InvalidAmount();
        if (feeAmount > amount) revert InvalidAmount();

        // Handle token transfer
        if (token == ETHAddress) {
            if (msg.value != amount) revert InvalidAmount();
        } else {
            if (msg.value != 0) revert InvalidAmount();
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        // Calculate admin fee
        uint256 adminFeeAmount = (feeAmount * adminFeeRate) / FEE_DENOMINATOR;
        uint256 remainingFee = feeAmount - adminFeeAmount;

        // Update balances - 记录实际保留的费用金额（扣除管理费后）
        feeBalances[token][feeType] += remainingFee;
        tokenBalances[token] += remainingFee;

        // Transfer admin fee to AdminFeeVault (before emitting event)
        if (adminFeeAmount > 0) {
            _transferToAdminFeeVault(token, adminFeeAmount, feeType, feeAmount);
        }

        emit FeeReceived(msg.sender, token, feeType, amount, feeAmount, adminFeeAmount);
    }

    /**
     * @notice Withdraw fees to a specified address
     * @param token The token address
     * @param to The recipient address
     * @param amount The amount to withdraw
     */
    function withdraw(address token, address to, uint256 amount) external onlyOwnerOrWithdrawManager {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (tokenBalances[token] < amount) revert InsufficientBalance();

        // Update total balance
        tokenBalances[token] -= amount;

        // Transfer tokens
        if (token == ETHAddress) {
            (bool success,) = to.call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit FeeWithdrawn(to, token, amount);
    }

    /**
     * @notice Set the withdraw manager address
     * @param _withdrawManager The new withdraw manager address
     */
    function setWithdrawManager(address _withdrawManager) external onlyOwner {
        address oldManager = withdrawManager;
        withdrawManager = _withdrawManager;

        emit WithdrawManagerUpdated(oldManager, _withdrawManager);
    }

    /**
     * @notice Set the AdminFeeVault address
     * @param _adminFeeVault The new AdminFeeVault address
     */
    function setAdminFeeVault(address _adminFeeVault) external onlyFeeVaultManager {
        if (_adminFeeVault == address(0)) revert InvalidAddress();

        address oldVault = adminFeeVault;
        adminFeeVault = _adminFeeVault;

        emit AdminFeeVaultUpdated(oldVault, _adminFeeVault);
    }

    /**
     * @notice Set the admin fee rate
     * @param _adminFeeRate The new admin fee rate (basis points)
     */
    function setAdminFeeRate(uint256 _adminFeeRate) external onlyFeeVaultManager {
        if (_adminFeeRate > MAX_ADMIN_FEE_RATE) revert InvalidFeeRate();

        uint256 oldRate = adminFeeRate;
        adminFeeRate = _adminFeeRate;

        emit AdminFeeRateUpdated(oldRate, _adminFeeRate);
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyFeeVaultManager {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyFeeVaultManager {
        _unpause();
    }

    /**
     * @notice Get the total balance of a token
     * @param token The token address
     * @return The total balance
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return tokenBalances[token];
    }

    /**
     * @notice Get the fee balance for a specific fee type
     * @param token The token address
     * @param feeType The fee type
     * @return The fee balance
     */
    function getFeeBalance(address token, uint8 feeType) external view returns (uint256) {
        return feeBalances[token][feeType];
    }

    /**
     * @notice Internal function to transfer admin fee to AdminFeeVault
     * @param token The token address
     * @param adminFeeAmount The admin fee amount
     * @param feeType The fee type
     * @param originalFeeAmount The original fee amount
     */
    function _transferToAdminFeeVault(address token, uint256 adminFeeAmount, uint8 feeType, uint256 originalFeeAmount)
        internal
    {
        if (token == ETHAddress) {
            IAdminFeeVault(adminFeeVault).receiveFee{value: adminFeeAmount}(
                token, adminFeeAmount, feeType, originalFeeAmount
            );
        } else {
            // Approve AdminFeeVault to pull tokens, then call receiveFee
            IERC20(token).forceApprove(adminFeeVault, adminFeeAmount);
            // AdminFeeVault will pull the tokens via transferFrom
            IAdminFeeVault(adminFeeVault).receiveFee(token, adminFeeAmount, feeType, originalFeeAmount);
        }

        emit AdminFeeTransferred(adminFeeVault, token, adminFeeAmount);
    }

    // Required to receive ETH
    receive() external payable {}
}
