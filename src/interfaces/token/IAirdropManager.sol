// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IAirdropManager {

    struct dropRewardInfo {
        address tokenAddress;
        address recipient;
        uint256 amount;
        uint8 airdropType;
    }

    event Withdraw(address indexed tokenAddress, address indexed recipient, uint256 amount);
    event SendReward(address indexed tokenAddress, address indexed recipient, uint256 amount, uint8 airdropType);

    function withdraw(address recipient, uint256 amount) external;
    function sendReward(address tokenAddress, address recipient, uint256 amount, uint8 airdropType) external;
    function sendRewards(dropRewardInfo[] memory drInfo) external;
}
