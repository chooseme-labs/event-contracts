// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {AirdropManagerStorage} from "./AirdropManagerStorage.sol";

contract AirdropManager is Initializable, OwnableUpgradeable, PausableUpgradeable, AirdropManagerStorage {
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
        require(_manager != address(0), "AirdropManager: manager cannot be zero address");
        manager = _manager;
    }

    /**
     * @dev Withdraw tokens from the reward pool
     * @param recipient Recipient address
     * @param amount Withdrawal amount
     */
    function withdraw(address recipient, uint256 amount) external onAuthorizedCaller {
        require(amount <= _tokenBalance(), "AirdropManager: withdraw amount more token balance in this contracts");

        IERC20(token).safeTransfer(recipient, amount);

        emit Withdraw(token, recipient, amount);
    }

    /**
     * @dev Send batch rewards to multiple recipients
     * @param drInfo Array of reward information structures containing token address, recipient, amount and airdrop type
     */
    function sendRewards(dropRewardInfo[] memory drInfo) external onAuthorizedCaller {
        for (uint256 i = 0; i < drInfo.length; i++) {
            distributeReward(
                drInfo[i].tokenAddress,
                drInfo[i].recipient,
                drInfo[i].amount,
                drInfo[i].airdropType
            );
        }
    }

    /**
     * @dev Send a single reward to a recipient
     * @param tokenAddress The ERC20 token contract address to transfer from
     * @param recipient The address that will receive the reward
     * @param amount The amount of tokens to send
     * @param airdropType The type/category of the airdrop (used for tracking and events)
     */
    function sendReward(address tokenAddress, address recipient, uint256 amount, uint8 airdropType) external onAuthorizedCaller {
        distributeReward(tokenAddress, recipient, amount,  airdropType);
    }

    // ========= internal =========
    /**
     * @dev Send reward to a recipient internal
     * @param tokenAddress The ERC20 token contract address to transfer from
     * @param recipient The address that will receive the reward
     * @param amount The amount of tokens to send
     * @param airdropType The type/category of the airdrop (used for tracking and events)
     */
    function distributeReward(address tokenAddress, address recipient, uint256 amount, uint8 airdropType) internal {
        require(recipient != address(0), "AirdropManager.sendRewards: zero address");
        require(amount > 0, "AirdropManager.sendRewards: amount must more than zero");
        IERC20(tokenAddress).safeTransfer(recipient, amount);
        emit SendReward(tokenAddress, recipient,amount, airdropType);
    }

    /**
     * @dev Get the token balance in the contract
     * @return Token balance in the contract
     */
    function _tokenBalance() internal view virtual returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
