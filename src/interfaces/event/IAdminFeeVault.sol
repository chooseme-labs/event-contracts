// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./IFeeVaultPod.sol";

interface IAdminFeeVault {
    // Events
    event FeeReceived(address indexed from, address indexed token, uint256 amount, uint8 feeType, uint256 feeAmount);
    event FeeWithdrawn(address indexed to, address indexed token, uint256 amount);

    // External functions (called by FeeVaultPod)
    function receiveFee(address token, uint256 amount, uint8 feeType, uint256 feeAmount) external payable;

    // Admin functions
    function withdraw(address token, address to, uint256 amount) external;

    function pause() external;
    function unpause() external;

    // View functions
    function getTokenBalance(address token) external view returns (uint256);
    function getFeeBalance(address token, uint8 feeType) external view returns (uint256);
}
