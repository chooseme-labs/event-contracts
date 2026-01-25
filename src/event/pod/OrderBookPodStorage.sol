// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../../interfaces/event/IOrderBookPod.sol";

abstract contract OrderBookPodStorage is IOrderBookPod {
    using EnumerableSet for EnumerableSet.UintSet;

    // State variables
    address public manager;
    address public eventPod;

    uint256 public orderIdCounter;
    uint256 public tradeIdCounter;

    // Mappings
    mapping(uint256 => Order) public orders; // orderId => Order
    mapping(uint256 => OrderBook) public orderBooks; // orderBookId => OrderBook
    mapping(address => EnumerableSet.UintSet) internal makerOrders; // maker => orderIds
    mapping(uint256 => EnumerableSet.UintSet) internal orderBookOrders; // orderBookId => orderIds

    // Price depth mappings for efficient order matching
    mapping(uint256 => EnumerableSet.UintSet) internal buyPriceLevels; // orderBookId => prices (sorted desc)
    mapping(uint256 => EnumerableSet.UintSet) internal sellPriceLevels; // orderBookId => prices (sorted asc)
    mapping(uint256 => mapping(uint256 => EnumerableSet.UintSet)) internal buyOrdersAtPrice; // orderBookId => price => orderIds
    mapping(uint256 => mapping(uint256 => EnumerableSet.UintSet)) internal sellOrdersAtPrice; // orderBookId => price => orderIds

    // Trade history
    mapping(uint256 => Trade) public trades; // tradeId => Trade
    mapping(uint256 => EnumerableSet.UintSet) internal orderBookTrades; // orderBookId => tradeIds

    uint256[100] private __gap;
}
