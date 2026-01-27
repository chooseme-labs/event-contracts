// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../../interfaces/event/IEventPod.sol";

abstract contract EventPodStorage {
    using EnumerableSet for EnumerableSet.UintSet;

    // State variables
    address public token; // USDT or other stablecoin address
    address public fundingPod; // FundingPod address
    address public orderBookPod; // OrderBookPod address
    address public feeVaultPod; // FeeVaultPod address
    address public oracle; // Oracle address
    address public manager; // EventManager address
    
    uint256 public defaultSettlementFeeRate; // Default settlement fee rate (basis points)
    
    // Event storage
    mapping(uint256 => IEventPod.Event) public events; // eventId => Event
    EnumerableSet.UintSet internal eventIds; // All event IDs
    EnumerableSet.UintSet internal activeEventIds; // Active event IDs
    
    // User positions
    mapping(uint256 => mapping(address => IEventPod.UserPosition)) public userPositions; // eventId => user => UserPosition
    
    // Oracle request tracking
    mapping(uint256 => uint256) public eventToRequestId; // eventId => requestId
    mapping(uint256 => uint256) public requestIdToEvent; // requestId => eventId
    
    // Storage gap for upgrades
    uint256[50] private __gap;
}

