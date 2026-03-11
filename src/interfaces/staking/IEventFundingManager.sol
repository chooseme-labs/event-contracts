// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEventFundingManager {
    event DepositToken(address indexed tokenAddress, address indexed sender, uint256 amount);

    function depositToken(address tokenAddress, uint256 amount) external returns (bool);
    function bettingEvent(address eventPod, address user, uint256 amount) external;
}
