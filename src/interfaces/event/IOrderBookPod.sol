// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOrderBookPod {
    enum OrderSide {
        Buy,
        Sell
    }

    enum OrderStatus {
        Pending,
        Partial,
        Filled,
        Cancelled
    }

    struct Order {
        uint256 orderId;
        address user;
        uint256 eventId;
        uint256 outcomeId;
        OrderSide side;
        uint256 price;
        uint256 amount;
        uint256 filledAmount;
        uint256 remainingAmount;
        OrderStatus status;
        uint256 timestamp;
        address tokenAddress;
    }

    event OrderPlaced(
        uint256 indexed orderId,
        address indexed user,
        uint256 indexed eventId,
        uint256 outcomeId,
        OrderSide side,
        uint256 price,
        uint256 amount
    );

    event OrderMatched(
        uint256 indexed buyOrderId,
        uint256 indexed sellOrderId,
        uint256 indexed eventId,
        uint256 outcomeId,
        uint256 price,
        uint256 amount
    );

    event OrderCancelled(
        uint256 indexed orderId,
        address indexed user,
        uint256 cancelledAmount
    );

    event EventSettled(uint256 indexed eventId, uint256 winningOutcomeId);

    event EventAdded(uint256 indexed eventId, uint256[] outcomeIds);

    error EventNotSupported(uint256 eventId);
    error OutcomeNotSupported(uint256 eventId, uint256 outcomeId);
    error EventAlreadySettled(uint256 eventId);
    error InvalidPrice(uint256 price);
    error InvalidAmount(uint256 amount);
    error PriceNotAlignedWithTickSize(uint256 price);
    error NotOrderOwner(uint256 orderId);
    error CannotCancelOrder(uint256 orderId);
    error EventMismatch(uint256 eventId1, uint256 eventId2);
    error OutcomeMismatch(uint256 outcomeId1, uint256 outcomeId2);

    function placeOrder(
        uint256 eventId,
        uint256 outcomeId,
        OrderSide side,
        uint256 price,
        uint256 amount,
        address tokenAddress
    ) external returns (uint256 orderId);

    function cancelOrder(uint256 orderId) external;

    function settleEvent(uint256 eventId, uint256 winningOutcomeId) external;

    function addEvent(uint256 eventId, uint256[] calldata outcomeIds) external;

    function getBestBid(
        uint256 eventId,
        uint256 outcomeId
    ) external view returns (uint256 price, uint256 amount);

    function getBestAsk(
        uint256 eventId,
        uint256 outcomeId
    ) external view returns (uint256 price, uint256 amount);
}
