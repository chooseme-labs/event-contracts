// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {FundingPodStorage} from "./FundingPodStorage.sol";
import {IFeeVaultPod} from "../../interfaces/event/IFeeVaultPod.sol";

contract FundingPod is Initializable, OwnableUpgradeable, PausableUpgradeable, FundingPodStorage {
    using SafeERC20 for IERC20;

    // Errors
    error OnlyFundingManager();
    error TokenNotSupported();
    error InvalidAmount();
    error InsufficientBalance();
    error InvalidAddress();
    error TransferFailed();

    // Modifiers
    modifier onlyFundingManager() {
        if (msg.sender != fundingManager) revert OnlyFundingManager();
        _;
    }

    modifier onlySupportedToken(address token) {
        if (!EnumerableSet.contains(supportTokens, token)) revert TokenNotSupported();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _fundingManager) external initializer {
        if (_owner == address(0) || _fundingManager == address(0)) revert InvalidAddress();

        __Ownable_init(_owner);
        __Pausable_init();

        fundingManager = _fundingManager;
    }

    /**
     * @notice User deposits tokens into the funding pod
     * @param token The token address to deposit (ETHAddress for native ETH)
     * @param amount The amount to deposit
     */
    function deposit(address token, uint256 amount) external payable whenNotPaused onlySupportedToken(token) {
        if (amount == 0) revert InvalidAmount();

        if (token == ETHAddress) {
            if (msg.value != amount) revert InvalidAmount();
        } else {
            if (msg.value != 0) revert InvalidAmount();
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        emit Deposit(msg.sender, token, amount);
    }

    /**
     * @notice Admin withdraws tokens for a user from the funding pod
     * @param user The user address to withdraw for
     * @param token The token address to withdraw
     * @param amount The amount to withdraw
     */
    function withdrawForUser(address user, address token, uint256 amount)
        external
        onlyFundingManager
        whenNotPaused
        onlySupportedToken(token)
    {
        if (amount == 0) revert InvalidAmount();
        if (user == address(0)) revert InvalidAddress();
        if (getTokenBalance(token) < amount) revert InsufficientBalance();

        if (token == ETHAddress) {
            (bool success,) = user.call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            IERC20(token).safeTransfer(user, amount);
        }

        emit Withdraw(user, token, amount);
    }

    /**
     * @notice Collect win fee from user rewards and transfer to FeeVaultPod
     * @param token The token address (ETHAddress for native ETH)
     * @param feeAmount The fee amount to transfer
     * @param feeType The fee type
     */
    function collectWinFee(address token, uint256 feeAmount, uint8 feeType)
        external
        onlyFundingManager
        whenNotPaused
        onlySupportedToken(token)
    {
        if (feeVaultPod == address(0)) revert InvalidAddress();
        if (feeAmount == 0) revert InvalidAmount();
        if (getTokenBalance(token) < feeAmount) revert InsufficientBalance();

        if (token == ETHAddress) {
            IFeeVaultPod(feeVaultPod).receiveFee{value: feeAmount}(token, feeAmount, feeType, feeAmount);
        } else {
            IERC20(token).forceApprove(feeVaultPod, feeAmount);
            IFeeVaultPod(feeVaultPod).receiveFee(token, feeAmount, feeType, feeAmount);
        }
    }

    /**
     * @notice Set the FeeVaultPod address
     * @param _feeVaultPod The new FeeVaultPod address
     */
    function setFeeVaultPod(address _feeVaultPod) external onlyFundingManager {
        if (_feeVaultPod == address(0)) revert InvalidAddress();
        feeVaultPod = _feeVaultPod;
    }

    /**
     * @notice Add a supported token
     * @param token The token address to add
     */
    function addSupportToken(address token) external onlyFundingManager {
        if (token == address(0)) revert InvalidAddress();
        EnumerableSet.add(supportTokens, token);
    }

    /**
     * @notice Remove a supported token
     * @param token The token address to remove
     */
    function removeSupportToken(address token) external onlyFundingManager {
        EnumerableSet.remove(supportTokens, token);
    }

    /**
     * @notice Check if a token is supported
     * @param token The token address
     * @return Whether the token is supported
     */
    function isSupportToken(address token) external view returns (bool) {
        return EnumerableSet.contains(supportTokens, token);
    }

    /**
     * @notice Get all supported tokens
     * @return Array of supported token addresses
     */
    function getSupportTokens() external view returns (address[] memory) {
        return EnumerableSet.values(supportTokens);
    }

    /**
     * @notice Get the total balance for a token
     * @param token The token address
     * @return The total balance
     */
    function getTokenBalance(address token) public view returns (uint256) {
        return token == ETHAddress ? address(this).balance : IERC20(token).balanceOf(address(this));
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Required to receive ETH
    receive() external payable {}
}
