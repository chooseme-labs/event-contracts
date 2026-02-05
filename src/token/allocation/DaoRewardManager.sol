// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {DaoRewardManagerStorage} from "./DaoRewardManagerStorage.sol";

contract DaoRewardManager is Initializable, OwnableUpgradeable, PausableUpgradeable, DaoRewardManagerStorage {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor() {
        _disableInitializers();
    }

    modifier onlyAuthorizedCaller() {
        require(authorizedCallers.contains(msg.sender), "onlyAuthorizedCaller");
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
     * @dev Initialize the DAO Reward Manager contract
     * @param initialOwner Initial owner address
     * @param _rewardTokenAddress Reward token address (CMT)
     */
    function initialize(address initialOwner, address _rewardTokenAddress) public initializer {
        __Ownable_init(initialOwner);
        manager = initialOwner;
        rewardTokenAddress = _rewardTokenAddress;
    }

    function setManager(address _manager) external onlyOwner {
        require(_manager != address(0), "DaoRewardManager: manager cannot be zero address");
        manager = _manager;
    }

    function setAuthorizedCaller(address caller, bool authorized) external onlyManager {
        if (authorized) {
            authorizedCallers.add(caller);
        } else {
            authorizedCallers.remove(caller);
        }
    }

    function getAuthorizedCallers() external view returns (address[] memory) {
        return EnumerableSet.values(authorizedCallers);
    }

    /**
     * @dev Withdraw tokens from the reward pool
     * @param recipient Recipient address
     * @param amount Withdrawal amount
     */
    function withdraw(address recipient, uint256 amount) external onlyAuthorizedCaller {
        require(amount <= _tokenBalance(), "DaoRewardManager: withdraw amount more token balance in this contracts");

        IERC20(rewardTokenAddress).safeTransfer(recipient, amount);
    }

    // ========= internal =========
    /**
     * @dev Get the token balance in the contract
     * @return Token balance in the contract
     */
    function _tokenBalance() internal view virtual returns (uint256) {
        return IERC20(rewardTokenAddress).balanceOf(address(this));
    }
}
