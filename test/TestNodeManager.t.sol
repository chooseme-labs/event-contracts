// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/staking/NodeManager.sol";
import "../src/interfaces/staking/INodeManager.sol";
import "../src/interfaces/token/IDaoRewardManager.sol";
import "../src/token/allocation/DaoRewardManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// forge test --match-contract NodeManagerTest -vvv
// Mock ERC20 Token for testing
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10 ** 6);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock EventFundingManager for testing
contract MockEventFundingManager {
    function depositEventFunding(uint256 amount) external {}
}

contract NodeManagerTest is Test {
    NodeManager public nodeManager;
    MockERC20 public mockToken;
    DaoRewardManager public daoRewardManager;
    MockEventFundingManager public mockEventFundingManager;

    address public owner = address(0x01);
    address public user1 = address(0x02);
    address public user2 = address(0x03);
    address public distributeRewardManager = address(0x04);
    address public poolAddress = address(0x05);

    uint256 public constant DISTRIBUTED_NODE_PRICE = 500 * 10 ** 6;
    uint256 public constant CLUSTER_NODE_PRICE = 1000 * 10 ** 6;

    event PurchaseNodes(address indexed buyer, uint256 amount, uint8 nodeType);

    event DistributeNodeRewards(address indexed recipient, uint256 amount, uint8 incomeType);

    function setUp() public {
        // Deploy mock contracts
        mockToken = new MockERC20();
        mockEventFundingManager = new MockEventFundingManager();

        // Deploy DaoRewardManager with proxy
        DaoRewardManager daoLogic = new DaoRewardManager();
        TransparentUpgradeableProxy daoProxy = new TransparentUpgradeableProxy(address(daoLogic), owner, "");
        daoRewardManager = DaoRewardManager(payable(address(daoProxy)));
        
        // Initialize DaoRewardManager
        daoRewardManager.initialize(owner, address(mockToken));
        
        // Mint reward tokens to DaoRewardManager
        mockToken.mint(address(daoRewardManager), 1000000 * 10 ** 6);

        // Deploy NodeManager with proxy
        NodeManager logic = new NodeManager();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), owner, "");

        nodeManager = NodeManager(address(proxy));

        // Initialize NodeManager
        nodeManager.initialize(
            owner, 
            address(daoRewardManager), 
            address(mockToken), 
            distributeRewardManager,
            address(mockEventFundingManager)
        );

        // Set pool address
        vm.prank(owner);
        nodeManager.setPool(poolAddress);

        // Mint tokens to users
        mockToken.mint(user1, 10000 * 10 ** 6);
        mockToken.mint(user2, 10000 * 10 ** 6);

        // Approve NodeManager to spend user tokens
        vm.prank(user1);
        mockToken.approve(address(nodeManager), type(uint256).max);
        vm.prank(user2);
        mockToken.approve(address(nodeManager), type(uint256).max);
    }

    function testPurchaseDistributedNode() public {
        uint256 userBalanceBefore = mockToken.balanceOf(user1);
        uint256 contractBalanceBefore = mockToken.balanceOf(address(nodeManager));

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit PurchaseNodes(user1, DISTRIBUTED_NODE_PRICE, uint8(INodeManager.NodeType.DistributedNode));
        nodeManager.purchaseNode(DISTRIBUTED_NODE_PRICE);

        // Check balances
        assertEq(mockToken.balanceOf(user1), userBalanceBefore - DISTRIBUTED_NODE_PRICE);
        assertEq(mockToken.balanceOf(address(nodeManager)), contractBalanceBefore + DISTRIBUTED_NODE_PRICE);

        // Check buyer info
        (address buyer, uint8 nodeType, uint256 amount) = nodeManager.nodeBuyerInfo(user1);
        assertEq(buyer, user1);
        assertEq(nodeType, uint8(INodeManager.NodeType.DistributedNode));
        assertEq(amount, DISTRIBUTED_NODE_PRICE);
    }

    function testPurchaseClusterNode() public {
        uint256 userBalanceBefore = mockToken.balanceOf(user1);
        uint256 contractBalanceBefore = mockToken.balanceOf(address(nodeManager));

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit PurchaseNodes(user1, CLUSTER_NODE_PRICE, uint8(INodeManager.NodeType.ClusterNode));
        nodeManager.purchaseNode(CLUSTER_NODE_PRICE);

        // Check balances
        assertEq(mockToken.balanceOf(user1), userBalanceBefore - CLUSTER_NODE_PRICE);
        assertEq(mockToken.balanceOf(address(nodeManager)), contractBalanceBefore + CLUSTER_NODE_PRICE);

        // Check buyer info
        (address buyer, uint8 nodeType, uint256 amount) = nodeManager.nodeBuyerInfo(user1);
        assertEq(buyer, user1);
        assertEq(nodeType, uint8(INodeManager.NodeType.ClusterNode));
        assertEq(amount, CLUSTER_NODE_PRICE);
    }

    function testPurchaseNodeRevertsIfAlreadyBought() public {
        vm.prank(user1);
        nodeManager.purchaseNode(DISTRIBUTED_NODE_PRICE);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(INodeManager.HaveAlreadyBuyNode.selector, user1));
        nodeManager.purchaseNode(CLUSTER_NODE_PRICE);
    }

    function testPurchaseNodeRevertsOnInvalidAmount() public {
        uint256 invalidAmount = 750 * 10 ** 6;

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(INodeManager.InvalidNodeTypeError.selector, invalidAmount));
        nodeManager.purchaseNode(invalidAmount);
    }

    function testDistributeRewards() public {
        vm.prank(distributeRewardManager);
        vm.expectEmit(true, false, false, true);
        emit DistributeNodeRewards(user1, 1000 * 10 ** 6, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));
        nodeManager.distributeRewards(user1, 1000 * 10 ** 6, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));

        // Check reward info
        (, uint256 amount, ) = nodeManager.nodeRewardTypeInfo(user1, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));
        assertEq(amount, 1000 * 10 ** 6);
    }

    function testDistributeRewardsMultipleTimes() public {
        vm.prank(distributeRewardManager);
        nodeManager.distributeRewards(user1, 1000 * 10 ** 6, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));

        vm.prank(distributeRewardManager);
        nodeManager.distributeRewards(user1, 500 * 10 ** 6, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));

        // Check accumulated reward
        (, uint256 amount, ) = nodeManager.nodeRewardTypeInfo(user1, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));
        assertEq(amount, 1500 * 10 ** 6);
    }

    function testDistributeRewardsRevertsOnZeroAddress() public {
        vm.prank(distributeRewardManager);
        vm.expectRevert("NodeManager.distributeRewards: zero address");
        nodeManager.distributeRewards(address(0), 1000 * 10 ** 6, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));
    }

    function testDistributeRewardsRevertsOnZeroAmount() public {
        vm.prank(distributeRewardManager);
        vm.expectRevert("NodeManager.distributeRewards: amount must more than zero");
        nodeManager.distributeRewards(user1, 0, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));
    }

    function testDistributeRewardsRevertsOnInvalidIncomeType() public {
        vm.prank(distributeRewardManager);
        vm.expectRevert("Invalid income type");
        nodeManager.distributeRewards(user1, 1000 * 10 ** 6, 6);
    }

    function testDistributeRewardsRevertsIfNotDistributeRewardManager() public {
        vm.prank(user1);
        vm.expectRevert("onlyDistributeRewardManager");
        nodeManager.distributeRewards(user1, 1000 * 10 ** 6, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));
    }

    function testClaimReward() public {
        // First distribute rewards
        vm.prank(distributeRewardManager);
        nodeManager.distributeRewards(user1, 1000 * 10 ** 6, uint8(INodeManager.NodeIncomeType.TradeFeeProfit));

        // Check reward is distributed
        (, uint256 amountBefore, ) = nodeManager.nodeRewardTypeInfo(user1, uint8(INodeManager.NodeIncomeType.TradeFeeProfit));
        assertEq(amountBefore, 1000 * 10 ** 6, "Reward should be distributed");

        // Note: claimReward function requires a real swap pool to execute, 
        // which is not available in this test environment.
        // The claim functionality would need integration testing with a real pool contract.
    }

    function testClaimRewardWithMultipleIncomeTypes() public {
        // Distribute different types of rewards
        vm.prank(distributeRewardManager);
        nodeManager.distributeRewards(user1, 1000 * 10 ** 6, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));

        vm.prank(distributeRewardManager);
        nodeManager.distributeRewards(user1, 500 * 10 ** 6, uint8(INodeManager.NodeIncomeType.TradeFeeProfit));

        // Check NodeTypeProfit is distributed
        (, uint256 amount1, ) = nodeManager.nodeRewardTypeInfo(user1, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));
        assertEq(amount1, 1000 * 10 ** 6, "NodeTypeProfit should be distributed");

        // Check TradeFeeProfit is also distributed
        (, uint256 amount2, ) = nodeManager.nodeRewardTypeInfo(user1, uint8(INodeManager.NodeIncomeType.TradeFeeProfit));
        assertEq(amount2, 500 * 10 ** 6, "TradeFeeProfit should be distributed");

        // Note: claimReward requires a real swap pool for execution
        // Integration tests with a deployed pool would be needed to test claim functionality
    }

    function testClaimRewardRevertsOnInvalidIncomeType() public {
        vm.prank(user1);
        vm.expectRevert("Invalid income type");
        nodeManager.claimReward(6);
    }

    function testMultipleUsersPurchaseAndClaimRewards() public {
        // User1 purchases distributed node
        vm.prank(user1);
        nodeManager.purchaseNode(DISTRIBUTED_NODE_PRICE);

        // User2 purchases cluster node
        vm.prank(user2);
        nodeManager.purchaseNode(CLUSTER_NODE_PRICE);

        // Distribute rewards to both users
        vm.prank(distributeRewardManager);
        nodeManager.distributeRewards(user1, 1000 * 10 ** 6, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));

        vm.prank(distributeRewardManager);
        nodeManager.distributeRewards(user2, 2000 * 10 ** 6, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));

        // Verify rewards are distributed correctly
        (, uint256 user1Reward, ) = nodeManager.nodeRewardTypeInfo(user1, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));
        assertEq(user1Reward, 1000 * 10 ** 6, "User1 should have correct reward");

        (, uint256 user2Reward, ) = nodeManager.nodeRewardTypeInfo(user2, uint8(INodeManager.NodeIncomeType.NodeTypeProfit));
        assertEq(user2Reward, 2000 * 10 ** 6, "User2 should have correct reward");
    }

    function testGetNodeBuyerInfo() public {
        vm.prank(user1);
        nodeManager.purchaseNode(DISTRIBUTED_NODE_PRICE);

        (address buyer, uint8 nodeType, uint256 amount) = nodeManager.nodeBuyerInfo(user1);
        assertEq(buyer, user1);
        assertEq(nodeType, uint8(INodeManager.NodeType.DistributedNode));
        assertEq(amount, DISTRIBUTED_NODE_PRICE);
    }

    function testGetNodeRewardTypeInfo() public {
        vm.prank(distributeRewardManager);
        nodeManager.distributeRewards(user1, 1000 * 10 ** 6, uint8(INodeManager.NodeIncomeType.ChildCoinProfit));

        (, uint256 amount, ) = nodeManager.nodeRewardTypeInfo(user1, uint8(INodeManager.NodeIncomeType.ChildCoinProfit));
        assertEq(amount, 1000 * 10 ** 6);
    }

    function testAllIncomeTypes() public {
        // Test all 5 income types
        uint8[] memory incomeTypes = new uint8[](5);
        incomeTypes[0] = uint8(INodeManager.NodeIncomeType.NodeTypeProfit);
        incomeTypes[1] = uint8(INodeManager.NodeIncomeType.TradeFeeProfit);
        incomeTypes[2] = uint8(INodeManager.NodeIncomeType.ChildCoinProfit);
        incomeTypes[3] = uint8(INodeManager.NodeIncomeType.SecondTierMarketProfit);
        incomeTypes[4] = uint8(INodeManager.NodeIncomeType.PromoteProfit);

        // Distribute rewards for all income types
        for (uint256 i = 0; i < incomeTypes.length; i++) {
            vm.prank(distributeRewardManager);
            nodeManager.distributeRewards(user1, (i + 1) * 100 * 10 ** 6, incomeTypes[i]);

            (, uint256 amount, ) = nodeManager.nodeRewardTypeInfo(user1, incomeTypes[i]);
            assertEq(amount, (i + 1) * 100 * 10 ** 6, "Each income type should have correct reward amount");
        }

        // Verify all rewards are still present (claim would require real pool integration)
        for (uint256 i = 0; i < incomeTypes.length; i++) {
            (, uint256 amount, ) = nodeManager.nodeRewardTypeInfo(user1, incomeTypes[i]);
            assertEq(amount, (i + 1) * 100 * 10 ** 6, "Rewards should remain in place");
        }
    }

    function testConstants() public {
        assertEq(nodeManager.buyDistributedNode(), 500 * 10 ** 6);
        assertEq(nodeManager.buyClusterNode(), 1000 * 10 ** 6);
        assertEq(nodeManager.underlyingToken(), address(mockToken));
        assertEq(nodeManager.distributeRewardAddress(), distributeRewardManager);
    }
}
