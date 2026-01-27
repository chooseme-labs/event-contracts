// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./IEventPod.sol";

interface IEventManager {
    // Events
    event EventPodCreated(address indexed podAddress);
    event DefaultSettlementFeeRateUpdated(uint256 oldRate, uint256 newRate);
    event DefaultOracleUpdated(address indexed oldOracle, address indexed newOracle);
    event DefaultFundingPodUpdated(address indexed oldPod, address indexed newPod);
    event DefaultOrderBookPodUpdated(address indexed oldPod, address indexed newPod);
    event DefaultFeeVaultPodUpdated(address indexed oldPod, address indexed newPod);

    // Errors
    error InvalidAddress();
    error InvalidFeeRate();
    error PodNotFound();

    // Admin functions - Event management (forward to EventPod)
    function createEvent(address pod, uint256 eventId, uint256 startTime, uint256 endTime, uint256 settlementFeeRate)
        external;

    function activateEvent(address pod, uint256 eventId) external;
    function cancelEvent(address pod, uint256 eventId) external;
    function requestEventResult(address pod, uint256 eventId) external;
    function settleEvent(address pod, uint256 eventId, IEventPod.EventResult result) external;

    // Admin functions - Pod configuration (forward to EventPod)
    function setFundingPod(address pod, address _fundingPod) external;
    function setOrderBookPod(address pod, address _orderBookPod) external;
    function setFeeVaultPod(address pod, address _feeVaultPod) external;
    function setOracle(address pod, address _oracle) external;
    function setSettlementFeeRate(address pod, uint256 _feeRate) external;

    // Admin functions - Pod control
    function pausePod(address pod) external;
    function unpausePod(address pod) external;
}
