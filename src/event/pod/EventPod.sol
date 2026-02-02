// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin-upgrades/contracts/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./EventPodStorage.sol";
import "../../interfaces/event/IEventPod.sol";
import "../../interfaces/event/IFundingPod.sol";
import "../../interfaces/event/IFeeVaultPod.sol";
import "../../interfaces/event/IOrderBookPod.sol";

contract EventPod is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC1155SupplyUpgradeable,
    EventPodStorage,
    IEventPod
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    // Constants
    uint256 public constant FEE_DENOMINATOR = 10000; // 100% = 10000 basis points
    uint256 public constant MAX_FEE_RATE = 1000; // 10% maximum

    // Modifiers
    modifier onlyManager() {
        if (msg.sender != manager) revert Unauthorized();
        _;
    }

    modifier onlyOrderBookPod() {
        if (msg.sender != orderBookPod) revert Unauthorized();
        _;
    }

    modifier onlyOracle() {
        if (msg.sender != oracle) revert Unauthorized();
        _;
    }

    modifier eventExists(uint256 eventId) {
        if (!eventIds.contains(eventId)) revert EventNotFound(eventId);
        _;
    }

    modifier eventActive(uint256 eventId) {
        if (events[eventId].status != EventStatus.ACTIVE) revert EventNotActive(eventId);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _manager,
        address _token,
        address _fundingPod,
        address _orderBookPod,
        address _feeVaultPod,
        address _oracle,
        uint256 _defaultSettlementFeeRate
    ) external initializer {
        if (_owner == address(0)) revert InvalidAddress();
        if (_manager == address(0)) revert InvalidAddress();
        if (_token == address(0)) revert InvalidAddress();
        if (_defaultSettlementFeeRate > MAX_FEE_RATE) revert InvalidSettlementFeeRate();

        __Ownable_init(_owner);
        __Pausable_init();
        __ERC1155_init("");

        manager = _manager;
        token = _token;
        fundingPod = _fundingPod;
        orderBookPod = _orderBookPod;
        feeVaultPod = _feeVaultPod;
        oracle = _oracle;
        defaultSettlementFeeRate = _defaultSettlementFeeRate;
    }

    // ============ Admin Functions (called by EventManager) ============

    function createEvent(uint256 eventId, uint256 startTime, uint256 endTime, uint256 settlementFeeRate)
        external
        override
        onlyManager
        whenNotPaused
    {
        if (eventIds.contains(eventId)) revert EventAlreadyExists(eventId);
        if (startTime >= endTime) revert InvalidEventTime();
        if (startTime < block.timestamp) revert InvalidEventTime();
        if (settlementFeeRate > MAX_FEE_RATE) revert InvalidSettlementFeeRate();

        Event storage newEvent = events[eventId];
        newEvent.eventId = eventId;
        newEvent.startTime = startTime;
        newEvent.endTime = endTime;
        newEvent.status = EventStatus.CREATED;
        newEvent.result = EventResult.PENDING;
        newEvent.settlementFeeRate = settlementFeeRate;
        newEvent.createdAt = block.timestamp;

        eventIds.add(eventId);

        emit EventCreated(eventId, startTime, endTime, settlementFeeRate);
    }

    function activateEvent(uint256 eventId) external override onlyManager eventExists(eventId) {
        Event storage evt = events[eventId];
        if (evt.status != EventStatus.CREATED) revert EventNotActive(eventId);

        evt.status = EventStatus.ACTIVE;
        activeEventIds.add(eventId);

        // Create OrderBooks for YES and NO tokens
        if (orderBookPod != address(0)) {
            IOrderBookPod(orderBookPod).createOrderBook(eventId, true); // YES token orderbook
            IOrderBookPod(orderBookPod).createOrderBook(eventId, false); // NO token orderbook
        }

        emit EventActivated(eventId);
    }

    function cancelEvent(uint256 eventId) external override onlyManager eventExists(eventId) {
        Event storage evt = events[eventId];
        if (evt.status == EventStatus.SETTLED) revert EventAlreadySettled(eventId);
        if (evt.status == EventStatus.CANCELLED) revert EventAlreadyCancelled(eventId);

        evt.status = EventStatus.CANCELLED;
        activeEventIds.remove(eventId);

        // Deactivate OrderBooks
        if (orderBookPod != address(0)) {
            uint256 yesOrderBookId = eventId * 10 + 1;
            uint256 noOrderBookId = eventId * 10 + 2;
            IOrderBookPod(orderBookPod).deactivateOrderBook(yesOrderBookId);
            IOrderBookPod(orderBookPod).deactivateOrderBook(noOrderBookId);
        }

        emit EventCancelled(eventId);
    }

    function requestEventResult(uint256 eventId) external override onlyManager eventExists(eventId) {
        Event storage evt = events[eventId];
        if (evt.status != EventStatus.ACTIVE) revert EventNotActive(eventId);
        if (block.timestamp < evt.endTime) revert EventNotEnded(eventId);

        evt.status = EventStatus.PENDING_RESULT;
        activeEventIds.remove(eventId);

        // In a real implementation, this would call the oracle
        // For now, we'll emit an event with a placeholder requestId
        uint256 requestId = uint256(keccak256(abi.encodePacked(eventId, block.timestamp)));
        eventToRequestId[eventId] = requestId;
        requestIdToEvent[requestId] = eventId;

        emit EventResultRequested(eventId, requestId);
    }

    function settleEvent(uint256 eventId, EventResult result) external override onlyManager eventExists(eventId) {
        Event storage evt = events[eventId];
        if (evt.status == EventStatus.SETTLED) revert EventAlreadySettled(eventId);
        if (result == EventResult.PENDING) revert InvalidResult();

        _settleEvent(eventId, result);
    }

    function setFundingPod(address _fundingPod) external override onlyManager {
        if (_fundingPod == address(0)) revert InvalidAddress();
        address oldPod = fundingPod;
        fundingPod = _fundingPod;
        emit FundingPodUpdated(oldPod, _fundingPod);
    }

    function setOrderBookPod(address _orderBookPod) external override onlyManager {
        address oldPod = orderBookPod;
        orderBookPod = _orderBookPod;
        emit OrderBookPodUpdated(oldPod, _orderBookPod);
    }

    function setFeeVaultPod(address _feeVaultPod) external override onlyManager {
        address oldPod = feeVaultPod;
        feeVaultPod = _feeVaultPod;
        emit FeeVaultPodUpdated(oldPod, _feeVaultPod);
    }

    function setOracle(address _oracle) external override onlyManager {
        address oldOracle = oracle;
        oracle = _oracle;
        emit OracleUpdated(oldOracle, _oracle);
    }

    function setDefaultSettlementFeeRate(uint256 _feeRate) external override onlyManager {
        if (_feeRate > MAX_FEE_RATE) revert InvalidSettlementFeeRate();
        uint256 oldRate = defaultSettlementFeeRate;
        defaultSettlementFeeRate = _feeRate;
        emit SettlementFeeRateUpdated(oldRate, _feeRate);
    }

    // ============ Helper Functions ============

    function getYesTokenId(uint256 eventId) public pure returns (uint256) {
        return eventId * 10 + 1;
    }

    function getNoTokenId(uint256 eventId) public pure returns (uint256) {
        return eventId * 10 + 2;
    }

    // ============ User Functions ============

    function splitShares(uint256 eventId, uint256 amount)
        external
        override
        whenNotPaused
        eventExists(eventId)
        eventActive(eventId)
    {
        if (amount == 0) revert InvalidAmount();

        Event storage evt = events[eventId];

        // Transfer USDT from FundingPod to this contract
        IFundingPod(fundingPod).transferToEvent(token, msg.sender, amount);

        // Update event total pool
        evt.totalPool += amount;

        // Mint YES and NO tokens to user (totalSupply is tracked by ERC1155Supply)
        uint256 yesTokenId = getYesTokenId(eventId);
        uint256 noTokenId = getNoTokenId(eventId);
        _mint(msg.sender, yesTokenId, amount, "");
        _mint(msg.sender, noTokenId, amount, "");

        emit SharesSplit(eventId, msg.sender, amount, amount, amount);
    }

    function mergeShares(uint256 eventId, uint256 amount)
        external
        override
        whenNotPaused
        eventExists(eventId)
        eventActive(eventId)
    {
        if (amount == 0) revert InvalidAmount();

        Event storage evt = events[eventId];
        uint256 yesTokenId = getYesTokenId(eventId);
        uint256 noTokenId = getNoTokenId(eventId);

        // Check if user has sufficient shares
        if (balanceOf(msg.sender, yesTokenId) < amount || balanceOf(msg.sender, noTokenId) < amount) {
            revert InsufficientShares();
        }

        // Burn YES and NO tokens from user (totalSupply is tracked by ERC1155Supply)
        _burn(msg.sender, yesTokenId, amount);
        _burn(msg.sender, noTokenId, amount);

        // Update event total pool
        evt.totalPool -= amount;

        // Transfer USDT back to FundingPod
        IERC20(token).approve(fundingPod, amount);
        IFundingPod(fundingPod).receiveFromEvent(token, msg.sender, amount);

        emit SharesMerged(eventId, msg.sender, amount, amount, amount);
    }

    function redeemFunds(uint256 eventId) external override whenNotPaused eventExists(eventId) {
        Event storage evt = events[eventId];
        if (evt.status != EventStatus.SETTLED && evt.status != EventStatus.CANCELLED) revert NotSettled();

        UserPosition storage userPosition = userPositions[eventId][msg.sender];
        if (userPosition.settled) revert AlreadySettled();

        uint256 claimableAmount = _calculateClaimableAmount(eventId, msg.sender);
        if (claimableAmount == 0) revert NoClaimableAmount();

        userPosition.settled = true;
        userPosition.claimedAmount = claimableAmount;

        // Burn redeemed shares
        uint256 yesTokenId = getYesTokenId(eventId);
        uint256 noTokenId = getNoTokenId(eventId);
        uint256 yesBalance = balanceOf(msg.sender, yesTokenId);
        uint256 noBalance = balanceOf(msg.sender, noTokenId);
        if (yesBalance > 0) {
            _burn(msg.sender, yesTokenId, yesBalance);
        }
        if (noBalance > 0) {
            _burn(msg.sender, noTokenId, noBalance);
        }

        // Transfer funds back to FundingPod
        IERC20(token).approve(fundingPod, claimableAmount);
        IFundingPod(fundingPod).receiveFromEvent(token, msg.sender, claimableAmount);

        emit FundsRedeemed(eventId, msg.sender, claimableAmount);
    }

    // ============ OrderBookPod Functions ============

    function updateShares(uint256 eventId, address user, bool isYes, int256 sharesDelta)
        external
        override
        onlyOrderBookPod
        eventExists(eventId)
        eventActive(eventId)
    {
        Event storage evt = events[eventId];
        uint256 tokenId = isYes ? getYesTokenId(eventId) : getNoTokenId(eventId);

        if (sharesDelta > 0) {
            // Buying shares - mint tokens
            uint256 delta = uint256(sharesDelta);
            _mint(user, tokenId, delta, "");

            // Transfer funds from FundingPod to EventPod
            IFundingPod(fundingPod).transferToEvent(token, user, delta);
            evt.totalPool += delta;
        } else if (sharesDelta < 0) {
            // Selling shares - burn tokens
            uint256 delta = uint256(-sharesDelta);
            if (balanceOf(user, tokenId) < delta) revert InsufficientShares();
            _burn(user, tokenId, delta);

            // Transfer funds from EventPod to FundingPod
            IERC20(token).approve(fundingPod, delta);
            IFundingPod(fundingPod).receiveFromEvent(token, user, delta);
            evt.totalPool -= delta;
        }

        emit SharesUpdated(eventId, user, isYes, sharesDelta, balanceOf(user, tokenId));
    }

    // ============ Oracle Callback ============

    function receiveResult(uint256 eventId, EventResult result) external override onlyOracle eventExists(eventId) {
        Event storage evt = events[eventId];
        if (evt.status != EventStatus.PENDING_RESULT) revert EventNotActive(eventId);
        if (result == EventResult.PENDING) revert InvalidResult();

        emit EventResultReceived(eventId, result);
        _settleEvent(eventId, result);
    }

    // ============ Internal Functions ============

    function _settleEvent(uint256 eventId, EventResult result) internal {
        Event storage evt = events[eventId];

        evt.status = EventStatus.SETTLED;
        evt.result = result;
        evt.settledAt = block.timestamp;

        // Deactivate OrderBooks
        if (orderBookPod != address(0)) {
            uint256 yesOrderBookId = eventId * 10 + 1;
            uint256 noOrderBookId = eventId * 10 + 2;
            IOrderBookPod(orderBookPod).deactivateOrderBook(yesOrderBookId);
            IOrderBookPod(orderBookPod).deactivateOrderBook(noOrderBookId);
        }

        // Calculate and transfer fees
        uint256 feeAmount = 0;
        if (result == EventResult.YES || result == EventResult.NO) {
            feeAmount = (evt.totalPool * evt.settlementFeeRate) / FEE_DENOMINATOR;

            if (feeAmount > 0 && feeVaultPod != address(0)) {
                IERC20(token).approve(feeVaultPod, feeAmount);
                IFeeVaultPod(feeVaultPod).receiveFee(token, feeAmount, IFeeVaultPod.FeeType.SETTLEMENT, feeAmount);
                emit FeeTransferred(eventId, feeVaultPod, feeAmount);
            }
        }

        emit EventSettled(eventId, result, evt.totalPool, feeAmount);
    }

    function _calculateClaimableAmount(uint256 eventId, address user) internal view returns (uint256) {
        Event storage evt = events[eventId];
        UserPosition storage userPosition = userPositions[eventId][user];

        if (userPosition.settled) {
            return 0;
        }

        uint256 yesTokenId = getYesTokenId(eventId);
        uint256 noTokenId = getNoTokenId(eventId);
        uint256 yesBalance = balanceOf(user, yesTokenId);
        uint256 noBalance = balanceOf(user, noTokenId);

        if (evt.status == EventStatus.CANCELLED) {
            // In case of cancellation, users get back their equal shares
            return yesBalance < noBalance ? yesBalance : noBalance;
        }

        if (evt.status != EventStatus.SETTLED) {
            return 0;
        }

        EventResult result = evt.result;

        if (result == EventResult.INVALID) {
            // Return equal shares
            return yesBalance < noBalance ? yesBalance : noBalance;
        }

        uint256 winningShares = result == EventResult.YES ? yesBalance : noBalance;
        if (winningShares == 0) {
            return 0;
        }

        // Use ERC1155Supply to get total supply of winning token
        uint256 winningTokenId = result == EventResult.YES ? yesTokenId : noTokenId;
        uint256 totalWinningShares = totalSupply(winningTokenId);
        if (totalWinningShares == 0) {
            return 0;
        }

        // Calculate claimable amount after fees
        uint256 totalPoolAfterFee = evt.totalPool - ((evt.totalPool * evt.settlementFeeRate) / FEE_DENOMINATOR);
        return (winningShares * totalPoolAfterFee) / totalWinningShares;
    }

    // ============ View Functions ============

    function getEvent(uint256 eventId) external view override returns (Event memory) {
        return events[eventId];
    }

    function getUserPosition(uint256 eventId, address user) external view override returns (UserPosition memory) {
        return userPositions[eventId][user];
    }

    function getClaimableAmount(uint256 eventId, address user) external view override returns (uint256) {
        return _calculateClaimableAmount(eventId, user);
    }

    function isEventActive(uint256 eventId) external view override returns (bool) {
        return activeEventIds.contains(eventId);
    }

    function getEventIds() external view override returns (uint256[] memory) {
        return eventIds.values();
    }

    function getActiveEventIds() external view override returns (uint256[] memory) {
        return activeEventIds.values();
    }

    function getYesSharesSupply(uint256 eventId) external view returns (uint256) {
        return totalSupply(getYesTokenId(eventId));
    }

    function getNoSharesSupply(uint256 eventId) external view returns (uint256) {
        return totalSupply(getNoTokenId(eventId));
    }

    function getUserYesShares(uint256 eventId, address user) external view returns (uint256) {
        return balanceOf(user, getYesTokenId(eventId));
    }

    function getUserNoShares(uint256 eventId, address user) external view returns (uint256) {
        return balanceOf(user, getNoTokenId(eventId));
    }

    // ============ Pausable Functions ============

    function pause() external override onlyManager {
        _pause();
    }

    function unpause() external override onlyManager {
        _unpause();
    }
}

