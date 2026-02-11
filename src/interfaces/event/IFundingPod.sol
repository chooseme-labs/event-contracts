// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./IFeeVaultPod.sol";

interface IFundingPod {
    // Events
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);

    // User functions
    function deposit(address token, uint256 amount) external payable;

    // Admin functions (called by FundingManager)
    function withdrawForUser(address user, address token, uint256 amount) external;
    function collectWinFee(address token, uint256 feeAmount, uint8 feeType) external;
    function setFeeVaultPod(address _feeVaultPod) external;
    function addSupportToken(address token) external;
    function removeSupportToken(address token) external;

    // View functions
    function isSupportToken(address token) external view returns (bool);
    function getSupportTokens() external view returns (address[] memory);
    function getTokenBalance(address token) external view returns (uint256);

    // Pausable functions
    function pause() external;
    function unpause() external;
}
