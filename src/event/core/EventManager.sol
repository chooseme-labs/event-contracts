// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../common/BaseManager.sol";
import "./EventManagerStorage.sol";
import "../pod/EventPod.sol";
import "../../interfaces/event/IEventManager.sol";
import "../../interfaces/event/IEventPod.sol";

contract EventManager is BaseManager, EventManagerStorage, IEventManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        if (_owner == address(0)) revert InvalidAddress();

        __Ownable_init(_owner);
    }

    // ============ Event Management Functions ============

    function createEvent(address pod, uint256 eventId, uint256 startTime, uint256 endTime, uint256 settlementFeeRate)
        external
        onlyOwner
        onlyPod(pod)
    {
        EventPod(payable(pod)).createEvent(eventId, startTime, endTime, settlementFeeRate);
    }

    function activateEvent(address pod, uint256 eventId) external override onlyOwner onlyPod(pod) {
        EventPod(payable(pod)).activateEvent(eventId);
    }

    function cancelEvent(address pod, uint256 eventId) external override onlyOwner onlyPod(pod) {
        EventPod(payable(pod)).cancelEvent(eventId);
    }

    function requestEventResult(address pod, uint256 eventId) external override onlyOwner onlyPod(pod) {
        EventPod(payable(pod)).requestEventResult(eventId);
    }

    function settleEvent(address pod, uint256 eventId, IEventPod.EventResult result)
        external
        override
        onlyOwner
        onlyPod(pod)
    {
        EventPod(payable(pod)).settleEvent(eventId, result);
    }

    // ============ Pod Configuration Functions ============

    function setFundingPod(address pod, address _fundingPod) external override onlyOwner onlyPod(pod) {
        if (_fundingPod == address(0)) revert InvalidAddress();
        EventPod(payable(pod)).setFundingPod(_fundingPod);
    }

    function setOrderBookPod(address pod, address _orderBookPod) external override onlyOwner onlyPod(pod) {
        EventPod(payable(pod)).setOrderBookPod(_orderBookPod);
    }

    function setFeeVaultPod(address pod, address _feeVaultPod) external override onlyOwner onlyPod(pod) {
        EventPod(payable(pod)).setFeeVaultPod(_feeVaultPod);
    }

    function setOracle(address pod, address _oracle) external override onlyOwner onlyPod(pod) {
        EventPod(payable(pod)).setOracle(_oracle);
    }

    function setSettlementFeeRate(address pod, uint256 _feeRate) external override onlyOwner onlyPod(pod) {
        EventPod(payable(pod)).setDefaultSettlementFeeRate(_feeRate);
    }

    // ============ Pod Control Functions ============

    function pausePod(address pod) external override onlyOwner onlyPod(pod) {
        EventPod(payable(pod)).pause();
    }

    function unpausePod(address pod) external override onlyOwner onlyPod(pod) {
        EventPod(payable(pod)).unpause();
    }
}

