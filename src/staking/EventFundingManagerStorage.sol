// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interfaces/staking/IEventFundingManager.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract EventFundingManagerStorage is IEventFundingManager {
    address public usdtTokenAddress;

    mapping(address => mapping(address => uint256)) public fundingBalanceForBetting;

    EnumerableSet.AddressSet internal authorizedCallers;

    address public manager;

    uint256[100] private __gap;
}
