// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/token/IDaoRewardManager.sol";
import "../interfaces/staking/IEventFundingManager.sol";
import "../interfaces/token/IChooseMeToken.sol";
import "./EventFundingManager.sol";
import "../utils/SwapHelper.sol";

import {NodeManagerStorage} from "./NodeManagerStorage.sol";

contract NodeManager is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuard, NodeManagerStorage {
    using SafeERC20 for IERC20;
    using SwapHelper for *;

    modifier onlyDistributeRewardManager() {
        require(msg.sender == address(distributeRewardAddress), "onlyDistributeRewardManager");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "onlyManager");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract
     * @param initialOwner Initial owner address
     * @param _usdt USDT address
     * @param _distributeRewardAddress Reward distribution manager address
     */
    function initialize(address initialOwner, address initialManager, address _usdt, address _distributeRewardAddress)
        public
        initializer
    {
        __Ownable_init(initialOwner);
        manager = initialManager;
        USDT = _usdt;
        distributeRewardAddress = _distributeRewardAddress;
    }

    function setManager(address _manager) external onlyOwner {
        manager = _manager;
    }

    function setDistributeRewardAddress(address _distributeRewardAddress) external onlyManager {
        distributeRewardAddress = _distributeRewardAddress;
    }

    /**
     * @dev setConfig
     * @param _daoRewardManager DAO reward manager contract address
     * @param _underlyingToken Underlying token address
     * @param _eventFundingManager Event funding manager contract address
     */
    function setConfig(address _underlyingToken, address _daoRewardManager, address _eventFundingManager)
        external
        onlyManager
    {
        underlyingToken = _underlyingToken;
        daoRewardManager = IDaoRewardManager(_daoRewardManager);
        eventFundingManager = IEventFundingManager(_eventFundingManager);
    }

    /**
     * @dev Purchase node - User side
     * @param amount Token amount required to purchase node, must match distributed node or cluster node price
     */
    function purchaseNode(uint256 amount) external {
        if (nodeBuyerInfo[msg.sender].amount > 0) {
            revert HaveAlreadyBuyNode(msg.sender);
        }
        require(inviters[msg.sender] != address(0), "inviter not set");

        uint8 buyNodeType = matchNodeTypeByAmount(amount);
        IERC20(USDT).safeTransferFrom(msg.sender, address(this), amount);
        NodeBuyerInfo memory buyerInfo = NodeBuyerInfo({buyer: msg.sender, nodeType: buyNodeType, amount: amount});
        nodeBuyerInfo[msg.sender] = buyerInfo;

        emit PurchaseNodes({buyer: msg.sender, amount: amount, nodeType: buyNodeType});
    }

    function bindInviter(address inviter) public {
        _bindInviter(inviter, msg.sender);
    }

    function _bindInviter(address inviter, address user) internal {
        require(inviter != address(0), "Inviter cannot be zero address");
        require(inviters[user] == address(0), "Inviter already set");
        require(inviters[inviter] != address(0), "Inviter has no inviter");

        inviters[user] = inviter;
        emit BindInviter({inviter: inviter, invitee: user});
    }

    /**
     * @dev Set root inviter - Only distribute reward manager can call
     * @param rootInviter Address to be set as root inviter
     * @param user Address of the user for whom the root inviter is being set
     */
    function bindRootInviter(address rootInviter, address user) external onlyManager {
        require(rootInviter != address(0) && user != address(0), "Root inviter and user cannot be zero address");
        require(inviters[user] == address(0), "Root inviter already set");

        inviters[user] = rootInviter;
        emit BindInviter({inviter: rootInviter, invitee: user});
    }

    function bindInviterBatch(address[] calldata inviters, address[] calldata invitees) external onlyManager {
        for (uint256 i = 0; i < inviters.length; i++) {
            _bindInviter(inviters[i], invitees[i]);
        }
    }

    function initNodeAmounts() external onlyManager {
        nodeAmounts[buyDistributedNode] = 600 * 10 ** 18;
        nodeAmounts[buyClusterNode] = 14000 * 10 ** 18;
    }

    /**
     * @dev Distribute node rewards (only reward distribution manager can call)
     * @param recipient Address receiving the reward
     * @param tokenAmount Token reward amount (CMT)
     * @param usdtAmount USDT equivalent reward amount
     * @param incomeType Income type (0 - node income, 1 - promotion income)
     */
    function distributeRewards(address recipient, uint256 tokenAmount, uint256 usdtAmount, uint8 incomeType)
        public
        onlyDistributeRewardManager
    {
        require(recipient != address(0), "NodeManager.distributeRewards: zero address");
        require(tokenAmount > 0 && usdtAmount > 0, "NodeManager.distributeRewards: amount must more than zero");
        require(incomeType <= uint256(NodeIncomeType.NodeIncomeCategorySameLevelFee), "Invalid income type");
        require(!rewardClaimInfo[recipient].isOutOf, "Recipient is out of rewards");

        uint256 usdtRewardAmount = usdtAmount;
        uint256 outAmount = nodeAmounts[nodeBuyerInfo[recipient].amount] * 3;
        if (rewardClaimInfo[recipient].totalUReward + usdtRewardAmount > outAmount) {
            usdtRewardAmount = outAmount - rewardClaimInfo[recipient].totalUReward;
        }

        rewardClaimInfo[recipient].totalUReward += usdtRewardAmount;
        tokenAmount = tokenAmount * usdtRewardAmount / usdtAmount;

        rewardClaimInfo[recipient].totalReward += tokenAmount;
        nodeRewardTypeInfo[recipient][incomeType].amount += tokenAmount;

        if (rewardClaimInfo[recipient].totalUReward >= outAmount) {
            rewardClaimInfo[recipient].isOutOf = true;
            emit outOfAchieveReturnsNodeExit({
                recipient: recipient, totalReward: rewardClaimInfo[recipient].totalReward, blockNumber: block.number
            });
        }
        emit DistributeNodeRewards({
            recipient: recipient, tokenAmount: tokenAmount, usdtAmount: usdtRewardAmount, incomeType: incomeType
        });
    }

    function distributeRewardBatch(BatchReward[] memory batchRewards) public onlyDistributeRewardManager {
        for (uint256 i = 0; i < batchRewards.length; i++) {
            BatchReward memory batchReward = batchRewards[i];
            distributeRewards(
                batchReward.recipient, batchReward.tokenAmount, batchReward.usdtAmount, batchReward.incomeType
            );
        }
    }

    /**
     * @dev Claim node rewards - User side
     * @param amount reward amount to claim
     * @notice 20% of rewards will be forcibly withheld and converted to USDT for deposit into event prediction market
     */
    function claimReward(uint256 amount) external {
        require(
            amount <= rewardClaimInfo[msg.sender].totalReward - rewardClaimInfo[msg.sender].claimedReward,
            "Claim amount mismatch"
        );

        rewardClaimInfo[msg.sender].claimedReward += amount;
        uint256 toEventPredictionAmount = (amount * 20) / 100;

        if (toEventPredictionAmount > 0) {
            daoRewardManager.withdraw(address(this), toEventPredictionAmount);

            uint256 usdtAmount =
                SwapHelper.swapV2(V2_ROUTER, underlyingToken, USDT, toEventPredictionAmount, 0, address(this));
            IERC20(USDT).approve(address(eventFundingManager), usdtAmount);
            eventFundingManager.depositUsdt(usdtAmount);
        }

        uint256 canWithdrawAmount = amount - toEventPredictionAmount;
        daoRewardManager.withdraw(msg.sender, canWithdrawAmount);

        emit ClaimReward({
            recipient: msg.sender, withdrawAmount: canWithdrawAmount, toPredictionAmount: toEventPredictionAmount
        });
    }

    /**
     * @dev Add liquidity to PancakeSwap V2 pool (only owner can call)
     * @param tokenAmount Total amount of underlying token to add
     * @param usdtAmount Total amount of USDT to add
     * @notice Convert 50% of USDT to underlying token, then add liquidity to V2
     */
    function addLiquidity(uint256 tokenAmount, uint256 usdtAmount, address to) external onlyManager {
        require(tokenAmount > 0 && usdtAmount > 0, "Amounts must be greater than 0");

        IERC20(underlyingToken).approve(V2_ROUTER, tokenAmount);
        IERC20(USDT).approve(V2_ROUTER, usdtAmount);
        (uint256 amount0Used, uint256 amount1Used, uint256 liquidityAdded) = IPancakeRouter02(V2_ROUTER)
            .addLiquidity(USDT, underlyingToken, usdtAmount, tokenAmount, 0, 0, to, block.timestamp);

        emit LiquidityAdded(liquidityAdded, amount0Used, amount1Used);
    }

    /**
     * @dev Match node type by amount
     * @param amount Purchase amount
     * @return Node type (0 - distributed node, 1 - cluster node)
     */
    function matchNodeTypeByAmount(uint256 amount) internal pure returns (uint8) {
        uint8 buyNodeType;
        if (amount == buyDistributedNode) {
            buyNodeType = uint8(NodeType.DistributedNode);
        } else if (amount == buyClusterNode) {
            buyNodeType = uint8(NodeType.ClusterNode);
        } else {
            revert InvalidNodeTypeError(amount);
        }
        return buyNodeType;
    }

    function withdrawUSDT(address recipient, uint256 amount) external onlyOwner {
        require(amount <= IERC20(USDT).balanceOf(address(this)), "withdraw amount more token balance in this contracts");
        IERC20(USDT).safeTransfer(recipient, amount);
        emit Withdraw(USDT, recipient, amount);
    }

    function purchaseNodeBatch(address[] calldata buyers, uint256[] calldata amounts) external onlyManager {
        for (uint256 i = 0; i < buyers.length; i++) {
            address buyer = buyers[i];
            uint256 amount = amounts[i];

            require(inviters[buyer] != address(0), "inviter not set");
            uint8 buyNodeType = matchNodeTypeByAmount(amount);
            NodeBuyerInfo memory buyerInfo = NodeBuyerInfo({buyer: buyer, nodeType: buyNodeType, amount: amount});
            nodeBuyerInfo[buyer] = buyerInfo;
            emit PurchaseNodes({buyer: buyer, amount: amount, nodeType: buyNodeType});
        }
    }

    function changeNodeBuyerInfo(address buyer, uint256 amount) public onlyManager {
        uint8 buyNodeType = matchNodeTypeByAmount(amount);
        nodeBuyerInfo[buyer].nodeType = buyNodeType;
        nodeBuyerInfo[buyer].amount = amount;
    }
}
