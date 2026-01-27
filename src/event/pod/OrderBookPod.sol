// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./OrderBookPodStorage.sol";
import "../../interfaces/event/IOrderBookPod.sol";
import "../../interfaces/event/IEventPod.sol";

contract OrderBookPod is Initializable, OwnableUpgradeable, PausableUpgradeable, OrderBookPodStorage {
    using EnumerableSet for EnumerableSet.UintSet;

    // Modifiers
    modifier onlyManager() {
        require(msg.sender == manager, "OrderBookPod: caller is not manager");
        _;
    }

    modifier onlyEventPod() {
        require(msg.sender == eventPod, "OrderBookPod: caller is not eventPod");
        _;
    }

    modifier orderBookExists(uint256 _orderBookId) {
        if (orderBooks[_orderBookId].orderBookId == 0) {
            revert OrderBookNotFound(_orderBookId);
        }
        _;
    }

    modifier orderBookActive(uint256 _orderBookId) {
        if (!orderBooks[_orderBookId].isActive) {
            revert OrderBookNotActive(_orderBookId);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _manager, address _eventPod) external initializer {
        if (_manager == address(0) || _eventPod == address(0)) {
            revert ZeroAddress();
        }

        __Ownable_init(msg.sender);
        __Pausable_init();

        manager = _manager;
        eventPod = _eventPod;
        orderIdCounter = 1;
        tradeIdCounter = 1;
    }

    // ============ OrderBook Management Functions ============

    function createOrderBook(uint256 _eventId, bool _isYesToken) external onlyEventPod returns (uint256 orderBookId) {
        // Calculate orderBookId: eventId * 10 + 1 (YES) or 2 (NO)
        orderBookId = _eventId * 10 + (_isYesToken ? 1 : 2);

        if (orderBooks[orderBookId].orderBookId != 0) {
            revert OrderBookAlreadyExists(orderBookId);
        }

        orderBooks[orderBookId] = OrderBook({
            orderBookId: orderBookId,
            eventId: _eventId,
            isYesToken: _isYesToken,
            isActive: true,
            totalBuyVolume: 0,
            totalSellVolume: 0
        });

        emit OrderBookCreated(orderBookId, _eventId, _isYesToken);
    }

    function deactivateOrderBook(uint256 _orderBookId) external onlyEventPod orderBookExists(_orderBookId) {
        orderBooks[_orderBookId].isActive = false;
        emit OrderBookDeactivated(_orderBookId);
    }

    function isOrderBookActive(uint256 _orderBookId) external view returns (bool) {
        return orderBooks[_orderBookId].isActive;
    }

    // ============ Order Placement Functions ============

    function placeLimitOrder(uint256 _orderBookId, OrderSide _side, uint256 _price, uint256 _amount)
        external
        whenNotPaused
        orderBookExists(_orderBookId)
        orderBookActive(_orderBookId)
        returns (uint256 orderId)
    {
        if (_price == 0) revert InvalidPrice();
        if (_amount == 0) revert InvalidAmount();

        orderId = _createOrder(_orderBookId, msg.sender, _side, OrderType.LIMIT, _price, _amount);

        // Try to match the order
        _matchOrder(orderId);

        // If order is not fully filled, add to order book
        Order storage order = orders[orderId];
        if (order.status == OrderStatus.OPEN || order.status == OrderStatus.PARTIALLY_FILLED) {
            _addOrderToBook(orderId);
        }
    }

    function placeMarketOrder(uint256 _orderBookId, OrderSide _side, uint256 _amount)
        external
        whenNotPaused
        orderBookExists(_orderBookId)
        orderBookActive(_orderBookId)
        returns (uint256 orderId)
    {
        if (_amount == 0) revert InvalidAmount();

        orderId = _createOrder(_orderBookId, msg.sender, _side, OrderType.MARKET, 0, _amount);

        // Match market order immediately
        _matchOrder(orderId);

        // Market orders that are not fully filled are cancelled
        Order storage order = orders[orderId];
        if (order.status != OrderStatus.FILLED) {
            order.status = OrderStatus.CANCELLED;
            emit OrderCancelled(orderId, order.maker);
        }
    }

    // ============ Order Cancellation Functions ============

    function cancelOrder(uint256 _orderId) external {
        Order storage order = orders[_orderId];

        if (order.orderId == 0) {
            revert OrderNotFound(_orderId);
        }
        if (order.maker != msg.sender && msg.sender != manager) {
            revert UnauthorizedCancellation(msg.sender, order.maker);
        }
        if (order.status == OrderStatus.CANCELLED) {
            revert OrderAlreadyCancelled(_orderId);
        }
        if (order.status == OrderStatus.FILLED) {
            revert OrderAlreadyFilled(_orderId);
        }

        _cancelOrder(_orderId);
    }

    function batchCancelOrders(uint256[] calldata _orderIds) external {
        for (uint256 i = 0; i < _orderIds.length; i++) {
            uint256 orderId = _orderIds[i];
            Order storage order = orders[orderId];

            if (order.orderId == 0) continue;
            if (order.maker != msg.sender && msg.sender != manager) continue;
            if (order.status == OrderStatus.CANCELLED || order.status == OrderStatus.FILLED) continue;

            _cancelOrder(orderId);
        }
    }

    // ============ Off-chain Matching Support ============

    function executeMatchedOrders(
        uint256 _orderBookId,
        uint256[] calldata _buyOrderIds,
        uint256[] calldata _sellOrderIds,
        uint256[] calldata _prices,
        uint256[] calldata _amounts
    ) external onlyManager orderBookExists(_orderBookId) orderBookActive(_orderBookId) {
        require(
            _buyOrderIds.length == _sellOrderIds.length && _sellOrderIds.length == _prices.length
                && _prices.length == _amounts.length,
            "OrderBookPod: array length mismatch"
        );

        for (uint256 i = 0; i < _buyOrderIds.length; i++) {
            _executeTrade(_orderBookId, _buyOrderIds[i], _sellOrderIds[i], _prices[i], _amounts[i]);
        }
    }

    // ============ View Functions ============

    function getOrder(uint256 _orderId) external view returns (Order memory) {
        return orders[_orderId];
    }

    function getOrderBook(uint256 _orderBookId) external view returns (OrderBook memory) {
        return orderBooks[_orderBookId];
    }

    function getOrdersByMaker(address _maker) external view returns (uint256[] memory) {
        return makerOrders[_maker].values();
    }

    function getActiveOrdersByOrderBook(uint256 _orderBookId) external view returns (uint256[] memory) {
        uint256[] memory allOrders = orderBookOrders[_orderBookId].values();
        uint256 activeCount = 0;

        // Count active orders
        for (uint256 i = 0; i < allOrders.length; i++) {
            Order storage order = orders[allOrders[i]];
            if (order.status == OrderStatus.OPEN || order.status == OrderStatus.PARTIALLY_FILLED) {
                activeCount++;
            }
        }

        // Create result array
        uint256[] memory activeOrders = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allOrders.length; i++) {
            Order storage order = orders[allOrders[i]];
            if (order.status == OrderStatus.OPEN || order.status == OrderStatus.PARTIALLY_FILLED) {
                activeOrders[index] = allOrders[i];
                index++;
            }
        }

        return activeOrders;
    }

    function getBuyOrders(uint256 _orderBookId) external view returns (uint256[] memory) {
        uint256[] memory allOrders = orderBookOrders[_orderBookId].values();
        uint256 buyCount = 0;

        for (uint256 i = 0; i < allOrders.length; i++) {
            if (orders[allOrders[i]].side == OrderSide.BUY) {
                buyCount++;
            }
        }

        uint256[] memory buyOrders = new uint256[](buyCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allOrders.length; i++) {
            if (orders[allOrders[i]].side == OrderSide.BUY) {
                buyOrders[index] = allOrders[i];
                index++;
            }
        }

        return buyOrders;
    }

    function getSellOrders(uint256 _orderBookId) external view returns (uint256[] memory) {
        uint256[] memory allOrders = orderBookOrders[_orderBookId].values();
        uint256 sellCount = 0;

        for (uint256 i = 0; i < allOrders.length; i++) {
            if (orders[allOrders[i]].side == OrderSide.SELL) {
                sellCount++;
            }
        }

        uint256[] memory sellOrders = new uint256[](sellCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allOrders.length; i++) {
            if (orders[allOrders[i]].side == OrderSide.SELL) {
                sellOrders[index] = allOrders[i];
                index++;
            }
        }

        return sellOrders;
    }

    function getBestBuyPrice(uint256 _orderBookId) external view returns (uint256) {
        uint256[] memory prices = buyPriceLevels[_orderBookId].values();
        if (prices.length == 0) return 0;

        uint256 bestPrice = prices[0];
        for (uint256 i = 1; i < prices.length; i++) {
            if (prices[i] > bestPrice) {
                bestPrice = prices[i];
            }
        }
        return bestPrice;
    }

    function getBestSellPrice(uint256 _orderBookId) external view returns (uint256) {
        uint256[] memory prices = sellPriceLevels[_orderBookId].values();
        if (prices.length == 0) return 0;

        uint256 bestPrice = prices[0];
        for (uint256 i = 1; i < prices.length; i++) {
            if (prices[i] < bestPrice) {
                bestPrice = prices[i];
            }
        }
        return bestPrice;
    }

    function getOrderBookDepth(uint256 _orderBookId, uint256 _levels)
        external
        view
        returns (
            uint256[] memory buyPrices,
            uint256[] memory buyAmounts,
            uint256[] memory sellPrices,
            uint256[] memory sellAmounts
        )
    {
        uint256[] memory allBuyPrices = buyPriceLevels[_orderBookId].values();
        uint256[] memory allSellPrices = sellPriceLevels[_orderBookId].values();

        // Sort buy prices descending
        allBuyPrices = _sortDescending(allBuyPrices);
        // Sort sell prices ascending
        allSellPrices = _sortAscending(allSellPrices);

        uint256 buyLevels = allBuyPrices.length < _levels ? allBuyPrices.length : _levels;
        uint256 sellLevels = allSellPrices.length < _levels ? allSellPrices.length : _levels;

        buyPrices = new uint256[](buyLevels);
        buyAmounts = new uint256[](buyLevels);
        sellPrices = new uint256[](sellLevels);
        sellAmounts = new uint256[](sellLevels);

        for (uint256 i = 0; i < buyLevels; i++) {
            buyPrices[i] = allBuyPrices[i];
            buyAmounts[i] = _getTotalAmountAtPrice(_orderBookId, allBuyPrices[i], OrderSide.BUY);
        }

        for (uint256 i = 0; i < sellLevels; i++) {
            sellPrices[i] = allSellPrices[i];
            sellAmounts[i] = _getTotalAmountAtPrice(_orderBookId, allSellPrices[i], OrderSide.SELL);
        }
    }

    // ============ Internal Functions ============

    function _createOrder(
        uint256 _orderBookId,
        address _maker,
        OrderSide _side,
        OrderType _orderType,
        uint256 _price,
        uint256 _amount
    ) internal returns (uint256 orderId) {
        orderId = orderIdCounter++;

        orders[orderId] = Order({
            orderId: orderId,
            orderBookId: _orderBookId,
            maker: _maker,
            side: _side,
            orderType: _orderType,
            price: _price,
            amount: _amount,
            filledAmount: 0,
            status: OrderStatus.OPEN,
            timestamp: block.timestamp
        });

        makerOrders[_maker].add(orderId);
        orderBookOrders[_orderBookId].add(orderId);

        emit OrderPlaced(orderId, _orderBookId, _maker, _side, _orderType, _price, _amount);
    }

    function _matchOrder(uint256 _orderId) internal {
        Order storage order = orders[_orderId];

        if (order.side == OrderSide.BUY) {
            _matchBuyOrder(_orderId);
        } else {
            _matchSellOrder(_orderId);
        }
    }

    function _matchBuyOrder(uint256 _buyOrderId) internal {
        Order storage buyOrder = orders[_buyOrderId];
        uint256[] memory sellPrices = sellPriceLevels[buyOrder.orderBookId].values();
        sellPrices = _sortAscending(sellPrices);

        for (uint256 i = 0; i < sellPrices.length && buyOrder.filledAmount < buyOrder.amount; i++) {
            uint256 sellPrice = sellPrices[i];

            // For limit orders, only match if price is acceptable
            if (buyOrder.orderType == OrderType.LIMIT && sellPrice > buyOrder.price) {
                break;
            }

            uint256[] memory sellOrderIds = sellOrdersAtPrice[buyOrder.orderBookId][sellPrice].values();

            for (uint256 j = 0; j < sellOrderIds.length && buyOrder.filledAmount < buyOrder.amount; j++) {
                uint256 sellOrderId = sellOrderIds[j];
                Order storage sellOrder = orders[sellOrderId];

                if (sellOrder.status != OrderStatus.OPEN && sellOrder.status != OrderStatus.PARTIALLY_FILLED) {
                    continue;
                }

                uint256 tradeAmount =
                    _min(buyOrder.amount - buyOrder.filledAmount, sellOrder.amount - sellOrder.filledAmount);

                _executeTrade(buyOrder.orderBookId, _buyOrderId, sellOrderId, sellPrice, tradeAmount);
            }
        }
    }

    function _matchSellOrder(uint256 _sellOrderId) internal {
        Order storage sellOrder = orders[_sellOrderId];
        uint256[] memory buyPrices = buyPriceLevels[sellOrder.orderBookId].values();
        buyPrices = _sortDescending(buyPrices);

        for (uint256 i = 0; i < buyPrices.length && sellOrder.filledAmount < sellOrder.amount; i++) {
            uint256 buyPrice = buyPrices[i];

            // For limit orders, only match if price is acceptable
            if (sellOrder.orderType == OrderType.LIMIT && buyPrice < sellOrder.price) {
                break;
            }

            uint256[] memory buyOrderIds = buyOrdersAtPrice[sellOrder.orderBookId][buyPrice].values();

            for (uint256 j = 0; j < buyOrderIds.length && sellOrder.filledAmount < sellOrder.amount; j++) {
                uint256 buyOrderId = buyOrderIds[j];
                Order storage buyOrder = orders[buyOrderId];

                if (buyOrder.status != OrderStatus.OPEN && buyOrder.status != OrderStatus.PARTIALLY_FILLED) {
                    continue;
                }

                uint256 tradeAmount =
                    _min(sellOrder.amount - sellOrder.filledAmount, buyOrder.amount - buyOrder.filledAmount);

                _executeTrade(sellOrder.orderBookId, buyOrderId, _sellOrderId, buyPrice, tradeAmount);
            }
        }
    }

    function _executeTrade(
        uint256 _orderBookId,
        uint256 _buyOrderId,
        uint256 _sellOrderId,
        uint256 _price,
        uint256 _amount
    ) internal {
        Order storage buyOrder = orders[_buyOrderId];
        Order storage sellOrder = orders[_sellOrderId];

        // Update filled amounts
        buyOrder.filledAmount += _amount;
        sellOrder.filledAmount += _amount;

        // Update order statuses
        if (buyOrder.filledAmount == buyOrder.amount) {
            buyOrder.status = OrderStatus.FILLED;
            _removeOrderFromBook(_buyOrderId);
            emit OrderFilled(_buyOrderId, buyOrder.filledAmount);
        } else if (buyOrder.filledAmount > 0) {
            buyOrder.status = OrderStatus.PARTIALLY_FILLED;
            emit OrderPartiallyFilled(_buyOrderId, buyOrder.filledAmount, buyOrder.amount - buyOrder.filledAmount);
        }

        if (sellOrder.filledAmount == sellOrder.amount) {
            sellOrder.status = OrderStatus.FILLED;
            _removeOrderFromBook(_sellOrderId);
            emit OrderFilled(_sellOrderId, sellOrder.filledAmount);
        } else if (sellOrder.filledAmount > 0) {
            sellOrder.status = OrderStatus.PARTIALLY_FILLED;
            emit OrderPartiallyFilled(_sellOrderId, sellOrder.filledAmount, sellOrder.amount - sellOrder.filledAmount);
        }

        // Record trade
        uint256 tradeId = tradeIdCounter++;
        trades[tradeId] = Trade({
            tradeId: tradeId,
            orderBookId: _orderBookId,
            buyOrderId: _buyOrderId,
            sellOrderId: _sellOrderId,
            buyer: buyOrder.maker,
            seller: sellOrder.maker,
            price: _price,
            amount: _amount,
            timestamp: block.timestamp
        });

        orderBookTrades[_orderBookId].add(tradeId);

        emit OrderMatched(
            tradeId, _orderBookId, _buyOrderId, _sellOrderId, buyOrder.maker, sellOrder.maker, _price, _amount
        );

        // Call EventPod to update shares
        // Determine if this is YES or NO token based on orderBookId
        OrderBook storage orderBook = orderBooks[_orderBookId];
        bool isYesToken = orderBook.isYesToken;
        uint256 eventId = orderBook.eventId;

        // Update buyer's shares (buying shares)
        IEventPod(eventPod).updateShares(eventId, buyOrder.maker, isYesToken, int256(_amount));

        // Update seller's shares (selling shares)
        IEventPod(eventPod).updateShares(eventId, sellOrder.maker, isYesToken, -int256(_amount));
    }

    function _cancelOrder(uint256 _orderId) internal {
        Order storage order = orders[_orderId];
        order.status = OrderStatus.CANCELLED;

        _removeOrderFromBook(_orderId);

        emit OrderCancelled(_orderId, order.maker);
    }

    function _addOrderToBook(uint256 _orderId) internal {
        Order storage order = orders[_orderId];

        if (order.side == OrderSide.BUY) {
            buyPriceLevels[order.orderBookId].add(order.price);
            buyOrdersAtPrice[order.orderBookId][order.price].add(_orderId);
            orderBooks[order.orderBookId].totalBuyVolume += (order.amount - order.filledAmount);
        } else {
            sellPriceLevels[order.orderBookId].add(order.price);
            sellOrdersAtPrice[order.orderBookId][order.price].add(_orderId);
            orderBooks[order.orderBookId].totalSellVolume += (order.amount - order.filledAmount);
        }
    }

    function _removeOrderFromBook(uint256 _orderId) internal {
        Order storage order = orders[_orderId];

        if (order.side == OrderSide.BUY) {
            buyOrdersAtPrice[order.orderBookId][order.price].remove(_orderId);
            if (buyOrdersAtPrice[order.orderBookId][order.price].length() == 0) {
                buyPriceLevels[order.orderBookId].remove(order.price);
            }
            uint256 remainingAmount = order.amount - order.filledAmount;
            if (orderBooks[order.orderBookId].totalBuyVolume >= remainingAmount) {
                orderBooks[order.orderBookId].totalBuyVolume -= remainingAmount;
            }
        } else {
            sellOrdersAtPrice[order.orderBookId][order.price].remove(_orderId);
            if (sellOrdersAtPrice[order.orderBookId][order.price].length() == 0) {
                sellPriceLevels[order.orderBookId].remove(order.price);
            }
            uint256 remainingAmount = order.amount - order.filledAmount;
            if (orderBooks[order.orderBookId].totalSellVolume >= remainingAmount) {
                orderBooks[order.orderBookId].totalSellVolume -= remainingAmount;
            }
        }
    }

    function _getTotalAmountAtPrice(uint256 _orderBookId, uint256 _price, OrderSide _side)
        internal
        view
        returns (uint256 total)
    {
        uint256[] memory orderIds;
        if (_side == OrderSide.BUY) {
            orderIds = buyOrdersAtPrice[_orderBookId][_price].values();
        } else {
            orderIds = sellOrdersAtPrice[_orderBookId][_price].values();
        }

        for (uint256 i = 0; i < orderIds.length; i++) {
            Order storage order = orders[orderIds[i]];
            if (order.status == OrderStatus.OPEN || order.status == OrderStatus.PARTIALLY_FILLED) {
                total += (order.amount - order.filledAmount);
            }
        }
    }

    function _sortAscending(uint256[] memory arr) internal pure returns (uint256[] memory) {
        uint256 n = arr.length;
        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = i + 1; j < n; j++) {
                if (arr[i] > arr[j]) {
                    (arr[i], arr[j]) = (arr[j], arr[i]);
                }
            }
        }
        return arr;
    }

    function _sortDescending(uint256[] memory arr) internal pure returns (uint256[] memory) {
        uint256 n = arr.length;
        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = i + 1; j < n; j++) {
                if (arr[i] < arr[j]) {
                    (arr[i], arr[j]) = (arr[j], arr[i]);
                }
            }
        }
        return arr;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
