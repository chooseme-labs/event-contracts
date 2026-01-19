// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../interfaces/event/IFeeVaultManager.sol";
import "../common/BaseManagerStorage.sol";

abstract contract FeeVaultManagerStorage is BaseManagerStorage, IFeeVaultManager {
    // Global AdminFeeVault address
    address public adminFeeVault;

    uint256[99] private __gap;
}
