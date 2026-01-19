// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./IFeeVaultPod.sol";

interface IFeeVaultManager {
    // Events
    event AdminFeeVaultUpdated(address indexed oldVault, address indexed newVault);

    // Admin functions - manage FeeVaultPods
    function setAdminFeeVault(address pod, address _adminFeeVault) external;
    function setAdminFeeRate(address pod, uint256 _adminFeeRate) external;
    function setGlobalAdminFeeVault(address _adminFeeVault) external;

    // View functions
    function adminFeeVault() external view returns (address);
}
