// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/event/pod/OrderBookPod.sol";
import "../src/event/core/OrderBookManager.sol";
import "../src/interfaces/event/IOrderBookPod.sol";

contract TestOrderBook is Test {
    OrderBookPod public orderBookPod;
    OrderBookManager public orderBookManager;

    address public owner = address(1);
    address public eventPod = address(2);
    address public user1 = address(3);
    address public user2 = address(4);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy contracts
        orderBookManager = new OrderBookManager();
        orderBookManager.initialize();

        orderBookPod = new OrderBookPod();
        orderBookPod.initialize(address(orderBookManager), eventPod);

        vm.stopPrank();
    }

    function testCreateOrderBook() public {
        vm.prank(eventPod);
        uint256 orderBookId = orderBookPod.createOrderBook(1, true);

        assertEq(orderBookId, 11); // eventId=1, isYesToken=true => 1*10+1=11

        IOrderBookPod.OrderBook memory ob = orderBookPod.getOrderBook(orderBookId);
        assertEq(ob.orderBookId, orderBookId);
        assertEq(ob.eventId, 1);
        assertTrue(ob.isYesToken);
        assertTrue(ob.isActive);
    }

    function testPlaceLimitOrder() public {
        // Create order book
        vm.prank(eventPod);
        uint256 orderBookId = orderBookPod.createOrderBook(1, true);

        // Place buy limit order
        vm.prank(user1);
        uint256 orderId = orderBookPod.placeLimitOrder(
            orderBookId,
            IOrderBookPod.OrderSide.BUY,
            100, // price
            1000 // amount
        );

        IOrderBookPod.Order memory order = orderBookPod.getOrder(orderId);
        assertEq(order.orderId, orderId);
        assertEq(order.maker, user1);
        assertEq(uint256(order.side), uint256(IOrderBookPod.OrderSide.BUY));
        assertEq(order.price, 100);
        assertEq(order.amount, 1000);
        assertEq(uint256(order.status), uint256(IOrderBookPod.OrderStatus.OPEN));
    }

    function testOrderMatching() public {
        // Create order book
        vm.prank(eventPod);
        uint256 orderBookId = orderBookPod.createOrderBook(1, true);

        // User1 places buy order at price 100
        vm.prank(user1);
        uint256 buyOrderId = orderBookPod.placeLimitOrder(orderBookId, IOrderBookPod.OrderSide.BUY, 100, 1000);

        // User2 places sell order at price 100 (should match)
        vm.prank(user2);
        uint256 sellOrderId = orderBookPod.placeLimitOrder(orderBookId, IOrderBookPod.OrderSide.SELL, 100, 500);

        // Check orders
        IOrderBookPod.Order memory buyOrder = orderBookPod.getOrder(buyOrderId);
        IOrderBookPod.Order memory sellOrder = orderBookPod.getOrder(sellOrderId);

        // Buy order should be partially filled
        assertEq(buyOrder.filledAmount, 500);
        assertEq(uint256(buyOrder.status), uint256(IOrderBookPod.OrderStatus.PARTIALLY_FILLED));

        // Sell order should be fully filled
        assertEq(sellOrder.filledAmount, 500);
        assertEq(uint256(sellOrder.status), uint256(IOrderBookPod.OrderStatus.FILLED));
    }

    function testCancelOrder() public {
        // Create order book
        vm.prank(eventPod);
        uint256 orderBookId = orderBookPod.createOrderBook(1, true);

        // Place order
        vm.prank(user1);
        uint256 orderId = orderBookPod.placeLimitOrder(orderBookId, IOrderBookPod.OrderSide.BUY, 100, 1000);

        // Cancel order
        vm.prank(user1);
        orderBookPod.cancelOrder(orderId);

        IOrderBookPod.Order memory order = orderBookPod.getOrder(orderId);
        assertEq(uint256(order.status), uint256(IOrderBookPod.OrderStatus.CANCELLED));
    }

    function testDeactivateOrderBook() public {
        // Create order book
        vm.prank(eventPod);
        uint256 orderBookId = orderBookPod.createOrderBook(1, true);

        assertTrue(orderBookPod.isOrderBookActive(orderBookId));

        // Deactivate
        vm.prank(eventPod);
        orderBookPod.deactivateOrderBook(orderBookId);

        assertFalse(orderBookPod.isOrderBookActive(orderBookId));
    }

    function testCannotPlaceOrderInInactiveOrderBook() public {
        // Create and deactivate order book
        vm.prank(eventPod);
        uint256 orderBookId = orderBookPod.createOrderBook(1, true);

        vm.prank(eventPod);
        orderBookPod.deactivateOrderBook(orderBookId);

        // Try to place order (should fail)
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IOrderBookPod.OrderBookNotActive.selector, orderBookId));
        orderBookPod.placeLimitOrder(orderBookId, IOrderBookPod.OrderSide.BUY, 100, 1000);
    }

    function testGetOrderBookDepth() public {
        // Create order book
        vm.prank(eventPod);
        uint256 orderBookId = orderBookPod.createOrderBook(1, true);

        // Place multiple buy orders at different prices
        vm.startPrank(user1);
        orderBookPod.placeLimitOrder(orderBookId, IOrderBookPod.OrderSide.BUY, 100, 1000);
        orderBookPod.placeLimitOrder(orderBookId, IOrderBookPod.OrderSide.BUY, 95, 2000);
        orderBookPod.placeLimitOrder(orderBookId, IOrderBookPod.OrderSide.BUY, 90, 1500);
        vm.stopPrank();

        // Place multiple sell orders at different prices
        vm.startPrank(user2);
        orderBookPod.placeLimitOrder(orderBookId, IOrderBookPod.OrderSide.SELL, 105, 800);
        orderBookPod.placeLimitOrder(orderBookId, IOrderBookPod.OrderSide.SELL, 110, 1200);
        vm.stopPrank();

        // Get order book depth
        (
            uint256[] memory buyPrices,
            uint256[] memory buyAmounts,
            uint256[] memory sellPrices,
            uint256[] memory sellAmounts
        ) = orderBookPod.getOrderBookDepth(orderBookId, 5);

        // Verify buy side (sorted descending)
        assertEq(buyPrices.length, 3);
        assertEq(buyPrices[0], 100); // Highest buy price
        assertEq(buyAmounts[0], 1000);

        // Verify sell side (sorted ascending)
        assertEq(sellPrices.length, 2);
        assertEq(sellPrices[0], 105); // Lowest sell price
        assertEq(sellAmounts[0], 800);
    }
}
