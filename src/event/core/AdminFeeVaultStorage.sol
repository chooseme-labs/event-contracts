// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../interfaces/event/IAdminFeeVault.sol";

abstract contract AdminFeeVaultStorage is IAdminFeeVault {
    address public constant ETHAddress = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    // Token balances for each fee type
    // token => feeType => balance
    mapping(address => mapping(uint8 => uint256)) public feeBalances;

    // Total token balances
    mapping(address => uint256) public tokenBalances;

    uint256[98] private __gap;
}
