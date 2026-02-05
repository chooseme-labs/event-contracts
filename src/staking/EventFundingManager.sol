// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {EventFundingManagerStorage} from "./EventFundingManagerStorage.sol";

contract EventFundingManager is Initializable, OwnableUpgradeable, PausableUpgradeable, EventFundingManagerStorage {
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    modifier onAuthorizedCaller() {
        require(EnumerableSet.contains(authorizedCallers, msg.sender), "DaoRewardManager: caller is not authorized");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "onlyManager");
        _;
    }

    /**
     * @dev Receive native tokens (BNB)
     */
    receive() external payable {}

    /**
     * @dev Initialize the Event Funding Manager contract
     * @param initialOwner Initial owner address
     * @param _usdtTokenAddress USDT token address
     */
    function initialize(address initialOwner, address _manager, address _usdtTokenAddress) public initializer {
        __Ownable_init(initialOwner);
        manager = _manager;
        usdtTokenAddress = _usdtTokenAddress;
    }

    function setManager(address _manager) external onlyOwner {
        manager = _manager;
    }

    /**
     * @dev Deposit USDT to the event funding pool
     * @param amount Amount of USDT to deposit
     * @return Whether the operation was successful
     */
    function depositUsdt(uint256 amount) external whenNotPaused returns (bool) {
        IERC20(usdtTokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        fundingBalanceForBetting[msg.sender][usdtTokenAddress] += amount;
        emit DepositUsdt(usdtTokenAddress, msg.sender, amount);
        return true;
    }

    /**
     * @dev Use funds to bet on event
     * @param eventPod Event pool address
     * @param user User address
     * @param amount Betting amount
     */
    function bettingEvent(address eventPod, address user, uint256 amount) external onAuthorizedCaller {
        require(fundingBalanceForBetting[user][usdtTokenAddress] >= amount, "amount is zero");

        fundingBalanceForBetting[user][usdtTokenAddress] -= amount;
        IERC20(usdtTokenAddress).safeTransfer(eventPod, amount);
    }

    function addAuthorizedCaller(address caller) external onlyManager {
        EnumerableSet.add(authorizedCallers, caller);
    }

    function removeAuthorizedCaller(address caller) external onlyManager {
        EnumerableSet.remove(authorizedCallers, caller);
    }

    function getAuthorizedCallers() external view returns (address[] memory) {
        return EnumerableSet.values(authorizedCallers);
    }
}
