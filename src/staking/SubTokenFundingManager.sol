// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../utils/SwapHelper.sol";

import {SubTokenFundingManagerStorage} from "./SubTokenFundingManagerStorage.sol";

contract SubTokenFundingManager is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    SubTokenFundingManagerStorage
{
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "onlyOperator");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == address(manager), "onlyManager");
        _;
    }

    /**
     * @dev Receive native tokens (BNB)
     */
    receive() external payable {}

    /**
     * @dev Initialize the Sub Token Funding Manager contract
     * @param initialOwner Initial owner address
     * @param _usdt USDT token address
     */
    function initialize(address initialOwner, address _manager, address _operator, address _usdt) public initializer {
        __Ownable_init(initialOwner);
        operator = _operator;
        manager = _manager;
        USDT = _usdt;
    }

    function setSubToken(address _subToken) external onlyManager {
        subToken = _subToken;
    }

    /**
     * @dev Set the operator address (only owner can call)
     * @param _operator New operator address
     */
    function setOperator(address _operator) external onlyManager {
        require(_operator != address(0), "SubTokenFundingManager: operator cannot be zero address");
        operator = _operator;
    }

    /**
     * @dev Set the manager address (only owner can call)
     * @param _manager New manager address
     */
    function setManager(address _manager) external onlyOwner {
        require(_manager != address(0), "SubTokenFundingManager: manager cannot be zero address");
        manager = _manager;
    }

    /**
     * @dev Add liquidity to trading pool
     * @param amount Amount of underlying token to add to liquidity pool
     */
    function addLiquidity(uint256 amount, uint256 price) external onlyOperator {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= IERC20(USDT).balanceOf(address(this)), "Insufficient balance");

        uint256 token0Amount = amount / 2;
        uint256 expectedToken1Amount = (token0Amount * price * 50) / 100 / 1e18;
        uint256 token1Amount =
            SwapHelper.swapV2(V2_ROUTER, USDT, subToken, token0Amount, expectedToken1Amount, address(this));
        (uint256 liquidityAdded, uint256 amount0Used, uint256 amount1Used) =
            SwapHelper.addLiquidityV2(V2_ROUTER, USDT, subToken, token0Amount, token1Amount, address(this));

        emit LiquidityAdded(liquidityAdded, amount0Used, amount1Used);
    }
}
