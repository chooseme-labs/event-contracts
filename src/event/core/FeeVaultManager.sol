// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../common/BaseManager.sol";
import "./FeeVaultManagerStorage.sol";
import "../pod/FeeVaultPod.sol";

contract FeeVaultManager is BaseManager, FeeVaultManagerStorage {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Errors
    error InvalidPod();
    error InvalidAddress();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the FeeVaultManager
     * @param _owner The owner address
     * @param _adminFeeVault The global AdminFeeVault address
     */
    function initialize(address _owner, address _adminFeeVault) external initializer {
        if (_owner == address(0) || _adminFeeVault == address(0)) revert InvalidAddress();

        __Ownable_init(_owner);

        adminFeeVault = _adminFeeVault;
    }

    /**
     * @notice Set the AdminFeeVault address for a specific pod
     * @param pod The FeeVaultPod address
     * @param _adminFeeVault The new AdminFeeVault address
     */
    function setAdminFeeVault(address pod, address _adminFeeVault) external onlyOwner onlyPod(pod) {
        FeeVaultPod(payable(pod)).setAdminFeeVault(_adminFeeVault);
    }

    /**
     * @notice Set the admin fee rate for a specific pod
     * @param pod The FeeVaultPod address
     * @param _adminFeeRate The new admin fee rate
     */
    function setAdminFeeRate(address pod, uint256 _adminFeeRate) external onlyOwner onlyPod(pod) {
        FeeVaultPod(payable(pod)).setAdminFeeRate(_adminFeeRate);
    }

    /**
     * @notice Set the global AdminFeeVault address
     * @param _adminFeeVault The new AdminFeeVault address
     */
    function setGlobalAdminFeeVault(address _adminFeeVault) external onlyOwner {
        if (_adminFeeVault == address(0)) revert InvalidAddress();

        address oldVault = adminFeeVault;
        adminFeeVault = _adminFeeVault;

        emit AdminFeeVaultUpdated(oldVault, _adminFeeVault);
    }

    /**
     * @notice Pause a FeeVaultPod
     * @param pod The FeeVaultPod address
     */
    function pausePod(address pod) external onlyOwner onlyPod(pod) {
        FeeVaultPod(payable(pod)).pause();
    }

    /**
     * @notice Unpause a FeeVaultPod
     * @param pod The FeeVaultPod address
     */
    function unpausePod(address pod) external onlyOwner onlyPod(pod) {
        FeeVaultPod(payable(pod)).unpause();
    }

    // Required to receive ETH
    receive() external payable {}
}
