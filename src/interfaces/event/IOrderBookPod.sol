// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOrderBookPod {
    // Enums
    enum OrderType {
        LIMIT, // 限价单
        MARKET // 市价单
    }

    enum OrderSide {
        BUY, // 买单
        SELL // 卖单
    }

    enum OrderStatus {
        OPEN, // 开放
        PARTIALLY_FILLED, // 部分成交
        FILLED, // 完全成交
        CANCELLED // 已取消
    }

    // Structs
    struct Order {
        uint256 orderId; // 订单ID
        uint256 orderBookId; // 订单簿ID
        address maker; // 下单者
        OrderSide side; // 买/卖
        OrderType orderType; // 限价/市价
        uint256 price; // 价格 (对于市价单，此值为0)
        uint256 amount; // 数量
        uint256 filledAmount; // 已成交数量
        OrderStatus status; // 订单状态
        uint256 timestamp; // 下单时间
    }

    struct OrderBook {
        uint256 orderBookId; // 订单簿ID
        uint256 eventId; // 事件ID
        bool isYesToken; // true=YES token, false=NO token
        bool isActive; // 是否激活
        uint256 totalBuyVolume; // 总买单量
        uint256 totalSellVolume; // 总卖单量
    }

    struct PriceLevel {
        uint256 price; // 价格
        uint256 totalAmount; // 该价格的总量
        uint256[] orderIds; // 该价格的订单ID列表
    }

    struct Trade {
        uint256 tradeId; // 交易ID
        uint256 orderBookId; // 订单簿ID
        uint256 buyOrderId; // 买单ID
        uint256 sellOrderId; // 卖单ID
        address buyer; // 买家
        address seller; // 卖家
        uint256 price; // 成交价格
        uint256 amount; // 成交数量
        uint256 timestamp; // 成交时间
    }

    // Events
    event OrderBookCreated(uint256 indexed orderBookId, uint256 indexed eventId, bool isYesToken);
    event OrderBookDeactivated(uint256 indexed orderBookId);
    event OrderPlaced(
        uint256 indexed orderId,
        uint256 indexed orderBookId,
        address indexed maker,
        OrderSide side,
        OrderType orderType,
        uint256 price,
        uint256 amount
    );
    event OrderCancelled(uint256 indexed orderId, address indexed maker);
    event OrderMatched(
        uint256 indexed tradeId,
        uint256 indexed orderBookId,
        uint256 buyOrderId,
        uint256 sellOrderId,
        address buyer,
        address seller,
        uint256 price,
        uint256 amount
    );
    event OrderFilled(uint256 indexed orderId, uint256 filledAmount);
    event OrderPartiallyFilled(uint256 indexed orderId, uint256 filledAmount, uint256 remainingAmount);

    // Errors
    error OrderBookNotFound(uint256 orderBookId);
    error OrderBookNotActive(uint256 orderBookId);
    error OrderBookAlreadyExists(uint256 orderBookId);
    error OrderNotFound(uint256 orderId);
    error InvalidOrderType();
    error InvalidOrderSide();
    error InvalidPrice();
    error InvalidAmount();
    error OrderAlreadyCancelled(uint256 orderId);
    error OrderAlreadyFilled(uint256 orderId);
    error UnauthorizedCancellation(address caller, address maker);
    error InsufficientLiquidity();
    error InvalidOrderBookId(uint256 orderBookId);
    error ZeroAddress();

    // Core Functions
    function initialize(address _manager, address _eventPod) external;

    // OrderBook Management (called by EventPod)
    function createOrderBook(uint256 _eventId, bool _isYesToken) external returns (uint256 orderBookId);
    function deactivateOrderBook(uint256 _orderBookId) external;
    function isOrderBookActive(uint256 _orderBookId) external view returns (bool);

    // Order Placement
    function placeLimitOrder(uint256 _orderBookId, OrderSide _side, uint256 _price, uint256 _amount)
        external
        returns (uint256 orderId);

    function placeMarketOrder(uint256 _orderBookId, OrderSide _side, uint256 _amount) external returns (uint256 orderId);

    // Order Cancellation
    function cancelOrder(uint256 _orderId) external;

    // Batch Operations
    function batchCancelOrders(uint256[] calldata _orderIds) external;

    // Off-chain Matching Support
    function executeMatchedOrders(
        uint256 _orderBookId,
        uint256[] calldata _buyOrderIds,
        uint256[] calldata _sellOrderIds,
        uint256[] calldata _prices,
        uint256[] calldata _amounts
    ) external;

    // View Functions
    function getOrder(uint256 _orderId) external view returns (Order memory);
    function getOrderBook(uint256 _orderBookId) external view returns (OrderBook memory);
    function getOrdersByMaker(address _maker) external view returns (uint256[] memory);
    function getActiveOrdersByOrderBook(uint256 _orderBookId) external view returns (uint256[] memory);
    function getBuyOrders(uint256 _orderBookId) external view returns (uint256[] memory);
    function getSellOrders(uint256 _orderBookId) external view returns (uint256[] memory);
    function getBestBuyPrice(uint256 _orderBookId) external view returns (uint256);
    function getBestSellPrice(uint256 _orderBookId) external view returns (uint256);
    function getOrderBookDepth(uint256 _orderBookId, uint256 _levels)
        external
        view
        returns (
            uint256[] memory buyPrices,
            uint256[] memory buyAmounts,
            uint256[] memory sellPrices,
            uint256[] memory sellAmounts
        );

    // State Variables View Functions
    function manager() external view returns (address);
    function eventPod() external view returns (address);
    function orderIdCounter() external view returns (uint256);
    function tradeIdCounter() external view returns (uint256);
}
