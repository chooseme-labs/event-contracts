// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IFeeVaultPod {
    // Events
    event FeeReceived(
        address indexed from,
        address indexed token,
        uint8 feeType,
        uint256 amount,
        uint256 feeAmount,
        uint256 adminFeeAmount
    );
    event FeeWithdrawn(address indexed to, address indexed token, uint256 amount);
    event AdminFeeTransferred(address indexed adminFeeVault, address indexed token, uint256 amount);
    event AdminFeeVaultUpdated(address indexed oldVault, address indexed newVault);
    event AdminFeeRateUpdated(uint256 oldRate, uint256 newRate);
    event WithdrawManagerUpdated(address indexed oldManager, address indexed newManager);

    // External functions called by other contracts
    function receiveFee(address token, uint256 amount, uint8 feeType, uint256 feeAmount) external payable;

    // Admin functions (called by owner or withdrawManager)
    function withdraw(address token, address to, uint256 amount) external;

    // Admin functions (called by owner)
    function setWithdrawManager(address _withdrawManager) external;

    // Admin functions (called by FeeVaultManager)
    function setAdminFeeVault(address _adminFeeVault) external;
    function setAdminFeeRate(uint256 _adminFeeRate) external;
    function pause() external;
    function unpause() external;

    // View functions
    function getTokenBalance(address token) external view returns (uint256);
    function getFeeBalance(address token, uint8 feeType) external view returns (uint256);
    function adminFeeVault() external view returns (address);
    function adminFeeRate() external view returns (uint256);
    function withdrawManager() external view returns (address);
}
