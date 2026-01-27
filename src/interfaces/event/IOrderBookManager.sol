// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./IOrderBookPod.sol";

interface IOrderBookManager {
    // Events
    event ExecutorUpdated(address indexed oldExecutor, address indexed newExecutor);
    event EmergencyOrderCancelled(uint256 indexed orderId, address indexed pod);
    event BatchOrdersCancelled(uint256[] orderIds, address indexed pod);

    // Errors
    error ZeroAddress();
    error NotAuthorized();
    error InvalidPod(address pod);

    // Management Functions
    function initialize() external;

    // Emergency Functions
    function emergencyCancelOrder(address _pod, uint256 _orderId) external;
    function emergencyBatchCancelOrders(address _pod, uint256[] calldata _orderIds) external;

    // Off-chain Matching Support
    function executeMatchedOrders(
        address _pod,
        uint256 _orderBookId,
        uint256[] calldata _buyOrderIds,
        uint256[] calldata _sellOrderIds,
        uint256[] calldata _prices,
        uint256[] calldata _amounts
    ) external;

    // View Functions
    function getOrderBookInfo(address _pod, uint256 _orderBookId) external view returns (IOrderBookPod.OrderBook memory);
    function getOrderInfo(address _pod, uint256 _orderId) external view returns (IOrderBookPod.Order memory);
}
