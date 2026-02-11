// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./AdminFeeVaultStorage.sol";

contract AdminFeeVault is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    AdminFeeVaultStorage
{
    using SafeERC20 for IERC20;

    // Errors
    error InvalidAddress();
    error InvalidAmount();
    error InsufficientBalance();
    error TransferFailed();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the AdminFeeVault
     * @param _owner The owner address
     */
    function initialize(address _owner) external initializer {
        if (_owner == address(0)) revert InvalidAddress();

        __Ownable_init(_owner);
        __Pausable_init();
    }

    /**
     * @notice Receive fee from FeeVaultPod contracts
     * @param token The token address (ETHAddress for native ETH)
     * @param amount The amount received
     * @param feeType The fee type
     * @param feeAmount The original fee amount (for tracking)
     */
    function receiveFee(address token, uint256 amount, uint8 feeType, uint256 feeAmount)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        if (amount == 0) revert InvalidAmount();

        // Handle token transfer
        if (token == ETHAddress) {
            if (msg.value != amount) revert InvalidAmount();
        } else {
            if (msg.value != 0) revert InvalidAmount();
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        // Update balances
        feeBalances[token][feeType] += amount;
        tokenBalances[token] += amount;

        emit FeeReceived(msg.sender, token, amount, feeType, feeAmount);
    }

    /**
     * @notice Withdraw fees to a specified address
     * @param token The token address
     * @param to The recipient address
     * @param amount The amount to withdraw
     */
    function withdraw(address token, address to, uint256 amount) external onlyOwner whenNotPaused {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (tokenBalances[token] < amount) revert InsufficientBalance();

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
     * @notice Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
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

    // Required to receive ETH
    receive() external payable {}
}
