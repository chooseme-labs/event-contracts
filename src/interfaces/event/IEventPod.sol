// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEventPod {
    // Enums
    enum EventStatus {
        CREATED, // 已创建
        ACTIVE, // 激活中
        PENDING_RESULT, // 等待结果
        SETTLED, // 已结算
        CANCELLED // 已取消
    }

    enum EventResult {
        PENDING, // 待定
        YES, // YES胜出
        NO, // NO胜出
        INVALID // 无效
    }

    // Structs
    struct Event {
        uint256 eventId; // 事件ID
        uint256 startTime; // 开始时间
        uint256 endTime; // 结束时间
        EventStatus status; // 事件状态
        EventResult result; // 事件结果
        uint256 totalPool; // 总资金池 (USDT)
        uint256 settlementFeeRate; // 结算费率 (basis points, 1/10000)
        uint256 createdAt; // 创建时间
        uint256 settledAt; // 结算时间
    }

    struct UserPosition {
        bool settled; // 是否已结算
        uint256 claimedAmount; // 已领取金额
    }

    // Events
    event EventCreated(uint256 indexed eventId, uint256 startTime, uint256 endTime, uint256 settlementFeeRate);
    event EventActivated(uint256 indexed eventId);
    event EventCancelled(uint256 indexed eventId);
    event EventResultRequested(uint256 indexed eventId, uint256 requestId);
    event EventResultReceived(uint256 indexed eventId, EventResult result);
    event EventSettled(uint256 indexed eventId, EventResult result, uint256 totalPool, uint256 feeAmount);

    event SharesSplit(
        uint256 indexed eventId, address indexed user, uint256 amount, uint256 yesShares, uint256 noShares
    );
    event SharesMerged(
        uint256 indexed eventId, address indexed user, uint256 amount, uint256 yesShares, uint256 noShares
    );

    event SharesUpdated(
        uint256 indexed eventId, address indexed user, bool isYes, int256 sharesDelta, uint256 newBalance
    );

    event FundsRedeemed(uint256 indexed eventId, address indexed user, uint256 amount);

    event FeeTransferred(uint256 indexed eventId, address indexed feeVault, uint256 amount);

    event FundingPodUpdated(address indexed oldPod, address indexed newPod);
    event OrderBookPodUpdated(address indexed oldPod, address indexed newPod);
    event FeeVaultPodUpdated(address indexed oldPod, address indexed newPod);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event SettlementFeeRateUpdated(uint256 oldRate, uint256 newRate);

    // Errors
    error EventNotFound(uint256 eventId);
    error EventNotActive(uint256 eventId);
    error EventAlreadyExists(uint256 eventId);
    error EventNotEnded(uint256 eventId);
    error EventAlreadySettled(uint256 eventId);
    error EventAlreadyCancelled(uint256 eventId);
    error InvalidEventTime();
    error InvalidSettlementFeeRate();
    error InvalidAmount();
    error InvalidShares();
    error InsufficientShares();
    error InsufficientBalance();
    error AlreadySettled();
    error NotSettled();
    error NoClaimableAmount();
    error InvalidAddress();
    error Unauthorized();
    error InvalidResult();

    // Admin functions (called by EventManager)
    function createEvent(uint256 eventId, uint256 startTime, uint256 endTime, uint256 settlementFeeRate) external;

    function activateEvent(uint256 eventId) external;
    function cancelEvent(uint256 eventId) external;
    function requestEventResult(uint256 eventId) external;
    function settleEvent(uint256 eventId, EventResult result) external;

    function setFundingPod(address _fundingPod) external;
    function setOrderBookPod(address _orderBookPod) external;
    function setFeeVaultPod(address _feeVaultPod) external;
    function setOracle(address _oracle) external;
    function setDefaultSettlementFeeRate(uint256 _feeRate) external;

    // User functions
    function splitShares(uint256 eventId, uint256 amount) external;
    function mergeShares(uint256 eventId, uint256 amount) external;
    function redeemFunds(uint256 eventId) external;

    // OrderBookPod functions (called by OrderBookPod during trading)
    function updateShares(uint256 eventId, address user, bool isYes, int256 sharesDelta) external;

    // Oracle callback
    function receiveResult(uint256 eventId, EventResult result) external;

    // View functions
    function getEvent(uint256 eventId) external view returns (Event memory);
    function getUserPosition(uint256 eventId, address user) external view returns (UserPosition memory);
    function getClaimableAmount(uint256 eventId, address user) external view returns (uint256);
    function isEventActive(uint256 eventId) external view returns (bool);
    function getEventIds() external view returns (uint256[] memory);
    function getActiveEventIds() external view returns (uint256[] memory);

    // Pausable functions
    function pause() external;
    function unpause() external;
}
