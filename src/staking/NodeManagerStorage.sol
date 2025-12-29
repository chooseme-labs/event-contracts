// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interfaces/staking/INodeManager.sol";
import "../interfaces/token/IDaoRewardManager.sol";


abstract contract NodeManagerStorage is INodeManager {
    uint256 public constant buyDistributedNode = 500 * 10 ** 6;
    uint256 public constant buyClusterNode = 1000 * 10 ** 6;
    address public constant tokenChoAddress = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address public constant tokenUsdtAddress = 0x55d398326f99059fF775485246999027B3197955;

    address public underlyingToken;
    address public distributeRewardAddress;

    IDaoRewardManager public daoRewardManager;

    mapping(address => NodeBuyerInfo) public nodeBuyerInfo;

    mapping(address => mapping(uint8 => NodeRewardInfo)) public nodeRewardTypeInfo;

    uint256[100] private __gap;
}
