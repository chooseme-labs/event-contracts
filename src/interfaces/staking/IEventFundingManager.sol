// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEventFundingManager {
    event DepositToken(address indexed tokenAddress, address indexed sender, uint256 amount);
    event WithdrawToken(address indexed tokenAddress, address indexed recipient, uint256 amount);
    function depositToken(address tokenAddress, uint256 amount) external returns (bool);
    function withdrawToken(address tokenAddress, address recipient, uint256 amount) external;
    function bettingEvent(address eventPod, address user, uint256 amount) external;
}
