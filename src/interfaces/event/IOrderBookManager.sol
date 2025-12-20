// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./IOrderBookPod.sol";

interface IOrderBookManager {
    function registerEventToPod(
        IOrderBookPod pod,
        uint256 eventId,
        uint256[] calldata outcomeIds
    ) external;

    function placeOrder(
        uint256 eventId,
        uint256 outcomeId,
        IOrderBookPod.OrderSide side,
        uint256 price,
        uint256 amount,
        address tokenAddress
    ) external returns (uint256 orderId);

    function cancelOrder(uint256 eventId, uint256 orderId) external;
}
