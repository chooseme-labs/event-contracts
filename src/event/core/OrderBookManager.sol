// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";

import "./OrderBookManagerStorage.sol";
import "../common/BaseManager.sol";
import "../../interfaces/event/IOrderBookPod.sol";

contract OrderBookManager is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    BaseManager,
    OrderBookManagerStorage
{
    // ============ Modifiers ============
    modifier onlyExecutor() {
        require(msg.sender == executor, "OrderBookManager: caller is not executor");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
    }

    // ============ Admin Functions ============

    function setExecutor(address _executor) external onlyOwner {
        require(_executor != address(0), "OrderBookManager: invalid executor address");
        address oldExecutor = executor;
        executor = _executor;
        emit ExecutorUpdated(oldExecutor, _executor);
    }

    // ============ Emergency Functions ============

    function emergencyCancelOrder(address _pod, uint256 _orderId) external onlyExecutor onlyPod(_pod) {
        IOrderBookPod(_pod).cancelOrder(_orderId);
        emit EmergencyOrderCancelled(_orderId, _pod);
    }

    function emergencyBatchCancelOrders(address _pod, uint256[] calldata _orderIds)
        external
        onlyExecutor
        onlyPod(_pod)
    {
        IOrderBookPod(_pod).batchCancelOrders(_orderIds);
        emit BatchOrdersCancelled(_orderIds, _pod);
    }

    // ============ Off-chain Matching Support ============

    function executeMatchedOrders(
        address _pod,
        uint256 _orderBookId,
        uint256[] calldata _buyOrderIds,
        uint256[] calldata _sellOrderIds,
        uint256[] calldata _prices,
        uint256[] calldata _amounts
    ) external onlyExecutor onlyPod(_pod) {
        IOrderBookPod(_pod).executeMatchedOrders(_orderBookId, _buyOrderIds, _sellOrderIds, _prices, _amounts);
    }

    // ============ View Functions ============

    function getOrderBookInfo(address _pod, uint256 _orderBookId)
        external
        view
        onlyPod(_pod)
        returns (IOrderBookPod.OrderBook memory)
    {
        return IOrderBookPod(_pod).getOrderBook(_orderBookId);
    }

    function getOrderInfo(address _pod, uint256 _orderId)
        external
        view
        onlyPod(_pod)
        returns (IOrderBookPod.Order memory)
    {
        return IOrderBookPod(_pod).getOrder(_orderId);
    }
}
