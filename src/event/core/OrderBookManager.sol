// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";

import "./OrderBookManagerStorage.sol";
import "../../interfaces/event/IOrderBookPod.sol";

contract OrderBookManager is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    OrderBookManagerStorage
{
    modifier onlyWhitelistedPod(IOrderBookPod pod) {
        require(podIsWhitelisted[pod], "OrderBookManager: pod not whitelisted");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialOwner) external initializer {
        __Ownable_init(_initialOwner);
        __Pausable_init();
    }

    function registerEventToPod(
        IOrderBookPod pod,
        uint256 eventId,
        uint256[] calldata outcomeIds
    ) external onlyOwner onlyWhitelistedPod(pod) {
        require(
            address(eventIdToPod[eventId]) == address(0),
            "OrderBookManager: event already registered"
        );
        eventIdToPod[eventId] = pod;
        pod.addEvent(eventId, outcomeIds);
    }

    function placeOrder(
        uint256 eventId,
        uint256 outcomeId,
        IOrderBookPod.OrderSide side,
        uint256 price,
        uint256 amount,
        address tokenAddress
    ) external whenNotPaused returns (uint256 orderId) {
        IOrderBookPod pod = eventIdToPod[eventId];
        require(
            address(pod) != address(0),
            "OrderBookManager: event not mapped"
        );
        require(podIsWhitelisted[pod], "OrderBookManager: pod not whitelisted");
        orderId = pod.placeOrder(
            eventId,
            outcomeId,
            side,
            price,
            amount,
            tokenAddress
        );
    }

    function cancelOrder(
        uint256 eventId,
        uint256 orderId
    ) external whenNotPaused {
        IOrderBookPod pod = eventIdToPod[eventId];
        require(
            address(pod) != address(0),
            "OrderBookManager: event not mapped"
        );
        require(podIsWhitelisted[pod], "OrderBookManager: pod not whitelisted");
        pod.cancelOrder(orderId);
    }

    function addPodToWhitelist(IOrderBookPod pod) external onlyOwner {
        podIsWhitelisted[pod] = true;
    }

    function removePodFromWhitelist(IOrderBookPod pod) external onlyOwner {
        podIsWhitelisted[pod] = false;
    }
}
