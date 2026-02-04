// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../interfaces/token/ITechManager.sol";

abstract contract TechManagerStorage is ITechManager {
    address public token;
    address public manager;

    // Authorized callers that can trigger token airdrops to compensate new user losses in prediction markets
    EnumerableSet.AddressSet internal authorizedCallers;

    uint256[100] private __gap;
}

