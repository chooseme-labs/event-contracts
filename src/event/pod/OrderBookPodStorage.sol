// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../interfaces/event/IOrderBookPod.sol";

abstract contract OrderBookPodStorage is IOrderBookPod {
    address public eventPod;
    address public fundingPod;
    address public feeVaultPod;
    address public orderBookManager;

    mapping(uint256 => bool) public supportedEvents;
    mapping(uint256 => mapping(uint256 => bool)) public supportedOutcomes;

    uint256 public nextOrderId;
    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;

    struct OutcomeOrderBook {
        mapping(uint256 => uint256[]) buyOrdersByPrice;
        uint256[] buyPriceLevels;
        mapping(uint256 => uint256[]) sellOrdersByPrice;
        uint256[] sellPriceLevels;
    }

    struct EventOrderBook {
        mapping(uint256 => OutcomeOrderBook) outcomeOrderBooks;
        uint256[] supportedOutcomes;
    }

    mapping(uint256 => EventOrderBook) internal eventOrderBooks;

    mapping(uint256 => mapping(uint256 => mapping(address => uint256)))
        public positions;

    uint256 public constant TICK_SIZE = 10;
    uint256 public constant MAX_PRICE = 10000;

    mapping(uint256 => bool) public eventSettled;
    mapping(uint256 => uint256) public eventResults;

    uint256[50] private __gap;
}
