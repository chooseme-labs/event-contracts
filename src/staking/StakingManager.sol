// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/staking/INodeManager.sol";
import "../interfaces/token/IDaoRewardManager.sol";
import "../interfaces/token/IChooseMeToken.sol";
import "../interfaces/staking/IEventFundingManager.sol";
import "../utils/SwapHelper.sol";

import {StakingManagerStorage} from "./StakingManagerStorage.sol";

contract StakingManager is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    StakingManagerStorage
{
    using SafeERC20 for IERC20;
    using SwapHelper for *;

    constructor() {
        _disableInitializers();
    }

    modifier onlyManager() {
        require(msg.sender == manager, "StakingManager: caller is not the manager");
        _;
    }

    modifier onlyStakingOperatorManager() {
        require(msg.sender == address(stakingOperatorManager), "onlyRewardDistributionManager");
        _;
    }

    /**
     * @dev Receive native tokens (BNB)
     */
    receive() external payable {}

    /**
     * @dev Initialize the Staking Manager contract
     * @param initialOwner Initial owner address
     * @param initialManager Initial manager address
     * @param _underlyingToken Underlying token address (CMT)
     * @param _stakingOperatorManager Staking operator manager address
     * @param _daoRewardManager DAO reward manager contract address
     * @param _eventFundingManager Event funding manager contract address
     */
    function initialize(
        address initialOwner,
        address initialManager,
        address _underlyingToken,
        address _usdt,
        address _stakingOperatorManager,
        address _daoRewardManager,
        address _eventFundingManager,
        address _nodeManager,
        address _subTokenFundingManager
    ) public initializer {
        __Ownable_init(initialOwner);
        manager = initialManager;
        underlyingToken = _underlyingToken;
        USDT = _usdt;
        stakingOperatorManager = _stakingOperatorManager;
        daoRewardManager = IDaoRewardManager(_daoRewardManager);
        eventFundingManager = IEventFundingManager(_eventFundingManager);
        nodeManager = INodeManager(_nodeManager);
        subTokenFundingManager = _subTokenFundingManager;
    }

    function setUnderlyingToken(address _underlyingToken) external onlyManager {
        underlyingToken = _underlyingToken;
    }

    /**
     * @dev Set the manager address (only owner can call)
     * @param _manager New manager address
     */
    function setManager(address _manager) external onlyOwner {
        require(_manager != address(0), "StakingManager: manager cannot be zero address");
        manager = _manager;
    }

    /**
     * @dev Liquidity provider staking deposit - User side
     * @param amount Staking amount, must match one of the staking types from T1-T6
     */
    function liquidityProviderDeposit(uint256 amount) external {
        require(nodeManager.inviters(msg.sender) != address(0), "inviter not set");
        require(amount >= userCurrentLiquidityAmount[msg.sender], "amount should more than previous staking amount");

        userCurrentLiquidityAmount[msg.sender] = amount;
        IERC20(USDT).safeTransferFrom(msg.sender, address(this), amount);
        (uint8 stakingType, uint256 endStakingTime) = liquidityProviderTypeAndAmount(amount);
        stakingTypeUsers[stakingType].push(msg.sender);

        uint256 round = lpStakingRound[msg.sender];
        StakingInfo storage lpInfo = liquidities[msg.sender][round];
        lpInfo.liquidityProvider = msg.sender;
        lpInfo.stakingType = stakingType;
        lpInfo.stakingAmount = amount;
        lpInfo.rewardUAmount = 0;
        lpInfo.rewardAmount = 0;
        lpInfo.claimedAmount = 0;

        emit LiquidityProviderDeposits(round, USDT, stakingType, msg.sender, amount, block.timestamp, endStakingTime);

        lpStakingRound[msg.sender] += 1;
        teamOutOfReward[msg.sender] = false;
    }

    /**
     * @dev Get liquidity providers list by type
     * @param stakingType Staking type (0-T1, 1-T2, ... 5-T6)
     * @return Address array of all liquidity providers of this type
     */
    function getLiquidityProvidersByType(uint8 stakingType) external view returns (address[] memory) {
        return stakingTypeUsers[stakingType];
    }

    /**
     * @dev Create liquidity provider reward (only staking operator manager can call)
     * @param lpAddress Liquidity provider address
     * @param round Staking round
     * @param tokenAmount Token reward amount
     * @param usdtAmount USDT reward amount
     * @param incomeType Income type (0 - daily normal reward, 1 - direct referral reward, 2 - team reward, 3 - sub equal reward, 4 - FOMO pool reward)
     */
    function createLiquidityProviderReward(
        address lpAddress,
        uint256 round,
        uint256 tokenAmount,
        uint256 usdtAmount,
        uint8 incomeType
    ) public onlyStakingOperatorManager {
        require(lpAddress != address(0), "zero address");
        require(tokenAmount > 0 && usdtAmount > 0, "amount should more than zero");

        StakingInfo storage lpInfo = liquidities[lpAddress][round];
        uint256 usdtRewardAmount = usdtAmount;
        bool reachedLimit = false;
        if (lpInfo.rewardUAmount + usdtRewardAmount >= lpInfo.stakingAmount * 3) {
            usdtRewardAmount = lpInfo.stakingAmount * 3 - lpInfo.rewardUAmount;
            reachedLimit = true;
        }
        require(usdtRewardAmount > 0, "reward reached limit");
        tokenAmount = tokenAmount * usdtRewardAmount / usdtAmount;

        lpInfo.rewardUAmount += usdtRewardAmount;
        lpInfo.rewardAmount += tokenAmount;
        lpInfo.rewards[incomeType] += tokenAmount;

        emit LiquidityProviderRewards({
            round: round,
            liquidityProvider: lpAddress,
            tokenAmount: tokenAmount,
            usdtAmount: usdtRewardAmount,
            rewardBlock: block.number,
            incomeType: incomeType
        });

        if (reachedLimit) {
            outOfAchieveReturnsNode(lpAddress, round, lpInfo.rewardUAmount);
        }
    }

    function createLiquidityProviderRewardBatch(BatchReward[] memory batchRewards) public onlyStakingOperatorManager {
        for (uint256 i = 0; i < batchRewards.length; i++) {
            createLiquidityProviderReward(
                batchRewards[i].lpAddress,
                batchRewards[i].round,
                batchRewards[i].tokenAmount,
                batchRewards[i].usdtAmount,
                batchRewards[i].incomeType
            );
        }
    }

    /**
     * @dev Liquidity provider claim reward - User side
     * @notice 20% of rewards will be forcibly withheld and converted to USDT for deposit into event prediction market
     */
    function liquidityProviderClaimReward(uint256 round) external nonReentrant {
        StakingInfo storage lpInfo = liquidities[msg.sender][round];
        uint256 amount = lpInfo.rewardAmount - lpInfo.claimedAmount;
        require(amount > 0, "reward insufficient");

        lpInfo.claimedAmount += amount;

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

        emit lpClaimReward({
            liquidityProvider: msg.sender,
            round: round,
            withdrawAmount: canWithdrawAmount,
            toPredictionAmount: toEventPredictionAmount
        });
    }

    /**
     * @dev Add liquidity to PancakeSwap V2 pool
     * @param amount Total amount of USDT to add
     * @notice Convert 50% of USDT to underlying token, then add liquidity to V2
     */
    function addLiquidity(uint256 amount, uint256 price) external onlyStakingOperatorManager {
        require(amount > 0, "Amount must be greater than 0");

        (uint256 liquidityAdded, uint256 amount0Used, uint256 amount1Used) =
            SwapHelper.addLiquidityV2(V2_ROUTER, USDT, underlyingToken, amount, price, address(this));
        emit LiquidityAdded(liquidityAdded, amount0Used, amount1Used);
    }

    /**
     * @dev Swap USDT for underlying token and burn
     * @param amount USDT amount to swap
     */
    function swapBurn(uint256 amount, uint256 subTokenUAmount) external onlyStakingOperatorManager {
        require(amount > 0, "Amount must be greater than 0");

        uint256 underlyingTokenReceived = SwapHelper.swapV2(V2_ROUTER, USDT, underlyingToken, amount, 0, address(this));
        require(underlyingTokenReceived > 0, "No tokens received from swap");
        IChooseMeToken(underlyingToken).burn(address(this), underlyingTokenReceived);

        IERC20(USDT).transfer(subTokenFundingManager, subTokenUAmount);

        emit TokensBurned(amount, underlyingTokenReceived);
    }

    // ==============internal function================
    /**
     * @dev Determine staking type and lock time based on staking amount
     * @param amount Staking amount
     * @return stakingType Staking type
     * @return stakingTimeInternal Lock time (seconds)
     */
    function liquidityProviderTypeAndAmount(uint256 amount) internal pure returns (uint8, uint256) {
        uint8 stakingType;
        uint256 stakingTimeInternal;
        if (amount == t1Staking) {
            stakingType = uint8(StakingType.T1);
            stakingTimeInternal = t1StakingTimeInternal;
        } else if (amount == t2Staking) {
            stakingType = uint8(StakingType.T2);
            stakingTimeInternal = t2StakingTimeInternal;
        } else if (amount == t3Staking) {
            stakingType = uint8(StakingType.T3);
            stakingTimeInternal = t3StakingTimeInternal;
        } else if (amount == t4Staking) {
            stakingType = uint8(StakingType.T4);
            stakingTimeInternal = t4StakingTimeInternal;
        } else if (amount == t5Staking) {
            stakingType = uint8(StakingType.T5);
            stakingTimeInternal = t5StakingTimeInternal;
        } else if (amount == t6Staking) {
            stakingType = uint8(StakingType.T6);
            stakingTimeInternal = t6StakingTimeInternal;
        } else {
            revert InvalidAmountError(amount);
        }

        return (stakingType, stakingTimeInternal);
    }

    /**
     * @dev Mark node as having reached team reward limit (3x staking amount)
     * @param lpAddress Liquidity provider address
     * @param totalReward Total team reward amount
     */
    function outOfAchieveReturnsNode(address lpAddress, uint256 round, uint256 totalReward) internal {
        teamOutOfReward[lpAddress] = true;

        emit outOfAchieveReturnsNodeExit({
            liquidityProvider: lpAddress, round: round, totalReward: totalReward, blockNumber: block.number
        });
    }

    function getLiquidityProviderInfo(address lpAddress, uint256 round)
        external
        view
        returns (StakingInfoOutput memory)
    {
        StakingInfo storage lpInfo = liquidities[lpAddress][round];

        uint rewardType = uint256(StakingRewardType.NodeIncomeCategorySameLevelFee) + 1
        uint256[] memory rewards = new uint256[](rewardType);
        for (uint8 i = 0; i < rewardType; i++) {
            rewards[i] = lpInfo.rewards[i];
        }

        return StakingInfoOutput({
            liquidityProvider: lpInfo.liquidityProvider,
            stakingType: lpInfo.stakingType,
            stakingAmount: lpInfo.stakingAmount,
            rewardUAmount: lpInfo.rewardUAmount,
            rewardAmount: lpInfo.rewardAmount,
            claimedAmount: lpInfo.claimedAmount,
            rewards: rewards
        });
    }
}
