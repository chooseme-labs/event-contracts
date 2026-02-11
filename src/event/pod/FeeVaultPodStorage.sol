// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../interfaces/event/IFeeVaultPod.sol";

abstract contract FeeVaultPodStorage is IFeeVaultPod {
    address public constant ETHAddress = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    // FeeVaultManager address
    address public feeVaultManager;

    // WithdrawManager address (can withdraw fees)
    address public withdrawManager;

    // AdminFeeVault address
    address public adminFeeVault;

    // Admin fee rate (basis points, e.g., 1000 = 10%)
    uint256 public adminFeeRate;

    // Token balances for each fee type
    // token => feeType => balance
    mapping(address => mapping(uint8 => uint256)) public feeBalances;

    // Total token balances
    mapping(address => uint256) public tokenBalances;

    uint256[94] private __gap;
}
