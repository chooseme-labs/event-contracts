// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {EcosystemManagerStorage} from "./EcosystemManagerStorage.sol";

contract EcosystemManager is Initializable, OwnableUpgradeable, PausableUpgradeable, EcosystemManagerStorage {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor() {
        _disableInitializers();
    }

    modifier onlyManager() {
        require(msg.sender == manager, "onlyManager");
        _;
    }

    modifier onAuthorizedCaller() {
        require(authorizedCallers.contains(msg.sender), "onAuthorizedCaller");
        _;
    }

    /**
     * @dev Initialize the DAO Reward Manager contract
     * @param initialOwner Initial owner address
     * @param _token Reward token address (CMT)
     */
    function initialize(address initialOwner, address initialManager, address _token) public initializer {
        __Ownable_init(initialOwner);
        manager = initialManager;
        token = _token;
    }

    /**
     * @dev Add an authorized caller
     * @param caller Address to be authorized
     */
    function addAuthorizedCaller(address caller) external onlyManager {
        authorizedCallers.add(caller);
    }

    /**
     * @dev Remove an authorized caller
     * @param caller Address to be removed from authorization
     */
    function removeAuthorizedCaller(address caller) external onlyManager {
        authorizedCallers.remove(caller);
    }

    function getAuthorizedCallers() external view returns (address[] memory) {
        return EnumerableSet.values(authorizedCallers);
    }

    /**
     * @dev Set the manager address (only owner can call)
     * @param _manager New manager address
     */
    function setManager(address _manager) external onlyOwner {
        require(_manager != address(0), "manager cannot be zero address");
        manager = _manager;
    }

    /**
     * @dev Withdraw tokens from the reward pool
     * @param recipient Recipient address
     * @param amount Withdrawal amount
     */
    function withdraw(address recipient, uint256 amount) external onAuthorizedCaller {
        require(amount <= _tokenBalance(), "withdraw amount more token balance in this contracts");

        IERC20(token).safeTransfer(recipient, amount);

        emit Withdraw(token, recipient, amount);
    }

    // ========= internal =========
    /**
     * @dev Get the token balance in the contract
     * @return Token balance in the contract
     */
    function _tokenBalance() internal view virtual returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
