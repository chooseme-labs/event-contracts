// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./InitContract.sol";

// MODE=1 forge script BroadcastStakingScript --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast

contract BroadcastStakingScript is InitContract {
    uint256 cmtDecimals = 10 ** 6;
    uint256 usdtDecimals = 10 ** 18;

    uint256 deployerPrivateKey;
    uint256 initPoolPrivateKey;
    uint256 user2PrivateKey;
    uint256 user3PrivateKey;
    uint256 user4PrivateKey;
    uint256 user5PrivateKey;

    function run() public {
        deployerPrivateKey = vm.envUint("DEV_PRIVATE_KEY");
        string memory mnemonic = vm.envString("DEV_MNEMONIC");
        initPoolPrivateKey = vm.deriveKey(mnemonic, 1);
        user2PrivateKey = vm.deriveKey(mnemonic, 2);
        user3PrivateKey = vm.deriveKey(mnemonic, 3);
        user4PrivateKey = vm.deriveKey(mnemonic, 4);
        user5PrivateKey = vm.deriveKey(mnemonic, 5);

        initContracts();

        // initChooseMeToken();
        // addLiquidity();
        transfer();
    }

    function initChooseMeToken() internal {
        if (chooseMeToken.balanceOf(address(daoRewardManager)) > 0) return;

        vm.startBroadcast(deployerPrivateKey);

        IChooseMeToken.ChooseMePool memory pools = IChooseMeToken.ChooseMePool({
            nodePool: vm.rememberKey(deployerPrivateKey),
            daoRewardPool: address(daoRewardManager),
            airdropPool: address(airdropManager),
            techPool: address(techManager),
            techFeePool: vm.rememberKey(deployerPrivateKey),
            capitalPool: address(capitalManager),
            marketingFeePool: vm.rememberKey(deployerPrivateKey),
            subTokenPool: address(subTokenFundingManager),
            ecosystemPool: address(marketManager)
        });
        address[] memory marketingPools = new address[](1);
        marketingPools[0] = vm.rememberKey(initPoolPrivateKey);

        chooseMeToken.setPoolAddress(pools, marketingPools);

        // Execute pool allocation
        chooseMeToken.poolAllocate();
        console.log("Pool allocation completed");
        console.log("Total Supply:", chooseMeToken.totalSupply() / cmtDecimals, "CMT");

        vm.stopBroadcast();
    }

    function addLiquidity() internal {
        address deployer = vm.rememberKey(deployerPrivateKey);
        uint256 cmtBalance = chooseMeToken.balanceOf(deployer);
        uint256 usdtBalance = usdt.balanceOf(deployer);

        if (cmtBalance == 0 || usdtBalance == 0) {
            console.log("Insufficient balance for adding liquidity");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        // Set liquidity amounts (can be adjusted as needed)
        uint256 cmtAmount = 1_000_000_00 * cmtDecimals;
        uint256 usdtAmount = 200_000 * usdtDecimals;

        // Approve tokens to router
        chooseMeToken.approve(address(pancakeRouter), cmtAmount);
        usdt.approve(address(pancakeRouter), usdtAmount);
        console.log("Tokens approved for PancakeSwap Router");

        // Add liquidity
        (uint256 amountA, uint256 amountB, uint256 liquidity) = pancakeRouter.addLiquidity(
            address(chooseMeToken),
            address(usdt),
            cmtAmount,
            usdtAmount,
            0, // amountAMin (slippage protection can be set)
            0, // amountBMin (slippage protection can be set)
            deployer, // LP tokens receiving address
            block.timestamp + 300 // Expires in 5 minutes
        );

        console.log("Liquidity added successfully");
        console.log("CMT amount:", amountA / cmtDecimals);
        console.log("USDT amount:", amountB / usdtDecimals);
        console.log("LP tokens:", liquidity);

        vm.stopBroadcast();
    }

    function transferGasFee(uint256 toPrivateKey) internal {
        address toAddress = vm.rememberKey(toPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        payable(toAddress).transfer(0.001 ether);
        vm.stopBroadcast();
    }

    function transfer() internal {
        vm.startBroadcast(deployerPrivateKey);
        usdt.transfer(0xB937d45E4934248A3af8107cB7f7A0848E831F9c, 100000 * usdtDecimals);
        return;

        usdt.transfer(0xAbD2177C975bc9E489FB77F624F08943123D5556, 100000 * usdtDecimals);
        usdt.transfer(0xE297a70704b652A4Bf0d378BB5159a502926d1B2, 100000 * usdtDecimals);
        usdt.transfer(0xCD5434571F95A4f4Cc013A9AE4addbF5281B6652, 100000 * usdtDecimals);
        usdt.transfer(0xE3953C725FC342870beBbfF6B6d271F36fBC29e4, 100000 * usdtDecimals);
        usdt.transfer(0xFd29d38110A23CaAf8DCFE0A04672c52BB1427c6, 100000 * usdtDecimals);
        usdt.transfer(0x0644C4Df6993EC6F3714D247C8C789a5837DdaAe, 100000 * usdtDecimals);
        usdt.transfer(0x2DA81495422b505bfcD393eF5A7631B6533055a0, 100000 * usdtDecimals);
        usdt.transfer(0x8A12Be137C9D15F64512b63cddBe60842BF1feeB, 100000 * usdtDecimals);
        usdt.transfer(0x70f5124744C0017243581416038582A85E108764, 100000 * usdtDecimals);
        usdt.transfer(0xBa9c39D33fB46F1e51FC9487981BccD7d31a0988, 100000 * usdtDecimals);
        usdt.transfer(0x74735058C8E84ffD525D75d7062Ae4B45bD122C5, 100000 * usdtDecimals);
        usdt.transfer(0x5d45D6d87DeBeDe9be9cf32f542DD07CDDF3C97f, 100000 * usdtDecimals);
        usdt.transfer(0xF26762816CB16A8A66F11418e167C3ff56896625, 100000 * usdtDecimals);
        usdt.transfer(0xF45614d9d3C2E73b394577b26bedF479f56B403b, 100000 * usdtDecimals);
        usdt.transfer(0x4FAD9057241eBf8a24a3710E15aF71acD584E38B, 100000 * usdtDecimals);
        usdt.transfer(0xfE702f06D5585B760Ab17bc5ae77258DDF9979b9, 100000 * usdtDecimals);
        usdt.transfer(0x9F5127a1A3C4af1C1A6Da736116Ff6A82539D535, 100000 * usdtDecimals);
        usdt.transfer(0xbfd6118Bb1Bdb5A8b7A6C1A484D82cC6a635DFBF, 100000 * usdtDecimals);
        usdt.transfer(0x334619B9a215C55749536170EbB3F53B611cDB79, 100000 * usdtDecimals);
        usdt.transfer(0x6BFeB66cd78C389Aea1E4c97F7737F299Fc890dE, 100000 * usdtDecimals);
        usdt.transfer(0x2b9d0C421926b9477f47C7f927E69Fe7267927A6, 100000 * usdtDecimals);
        usdt.transfer(0x5CC07DC3990E62Fa8A33aF125d2B156909358041, 100000 * usdtDecimals);
        usdt.transfer(0x2944D245360e76818216FF6a7897A487AdA0e567, 100000 * usdtDecimals);
        usdt.transfer(0xEF73040b170a8085F6Fd8Be3A2568e20c171Fe89, 100000 * usdtDecimals);
        usdt.transfer(0x29F6C1fd48EE094F16922b6f9c9856bA1D5582c8, 100000 * usdtDecimals);
        usdt.transfer(0x151EdA5210E4c6fF098536BEeAe72F389d34122E, 100000 * usdtDecimals);
        usdt.transfer(0x8e6BD036f6799178fC8Fb72656bb94ca517A7398, 100000 * usdtDecimals);
        usdt.transfer(0x71115B9AF31Cd7A84C617831964ad825164EdC0e, 100000 * usdtDecimals);
        usdt.transfer(0xbB0605d260b4c985e52E10314Ade41E02677ef33, 100000 * usdtDecimals);
        usdt.transfer(0x39834cff404bbA328087CAdEA8442fe290de6646, 100000 * usdtDecimals);
        usdt.transfer(0xaE493cD22f60527F8840AE54730614BdAF8A71A2, 100000 * usdtDecimals);
        usdt.transfer(0xD094244227259AcF88Bdd3a84C6EcE32aa730B2F, 100000 * usdtDecimals);
        usdt.transfer(0xdAD1Db20fd24e20D5ED718F9E38953AF3C9333bb, 100000 * usdtDecimals);
        usdt.transfer(0x4aab6761DED0d999D4f2C3C9b5242e28aC921C2D, 100000 * usdtDecimals);
        usdt.transfer(0xe687058486dD8643E959e077e06D2f9B6Ab14C1d, 100000 * usdtDecimals);
        usdt.transfer(0xfEaE9604a52E3fF7b0477AC428d6d15801a71ce3, 100000 * usdtDecimals);
        usdt.transfer(0xE9B8727A2b40E79944D2EBc699c675eCD39f687D, 100000 * usdtDecimals);
        usdt.transfer(0x15F258DFc55103d3228fD2B5e210101B81f515d8, 100000 * usdtDecimals);
        usdt.transfer(0xa5184Eee60897A5a94F3255696dcC527890DBd59, 100000 * usdtDecimals);
        vm.stopBroadcast();
    }

    function swap(uint256 userPrivateKey, address token0, address token1, uint256 amount0) internal {
        address userAddress = vm.rememberKey(userPrivateKey);
        address initPoolAddress = vm.rememberKey(initPoolPrivateKey);
        address deployerAddress = vm.rememberKey(deployerPrivateKey);

        // Step 1: Transfer token0 from initPoolPrivateKey to user address
        vm.startBroadcast(initPoolPrivateKey);
        ERC20(token0).transfer(userAddress, amount0);
        console.log("Transferred token0 to user address");
        console.log("Amount:", amount0);
        vm.stopBroadcast();

        // Step 2: Estimate transaction gas fee
        uint256 estimatedGas = 300000; // Estimated gas limit
        uint256 gasPrice = tx.gasprice;
        uint256 gasCost = estimatedGas * gasPrice;

        console.log("Estimated gas:", estimatedGas);
        console.log("Gas price:", gasPrice);
        console.log("Estimated gas cost:", gasCost);

        // Step 3: Transfer gas fee (BNB) from deployerPrivateKey to user address
        vm.startBroadcast(deployerPrivateKey);
        payable(userAddress).transfer(gasCost);
        console.log("Transferred gas fee to user address");
        console.log("Gas fee amount (BNB):", gasCost);
        vm.stopBroadcast();

        // Step 4: Execute swap transaction using user private key
        vm.startBroadcast(userPrivateKey);

        // Approve token0 to router
        ERC20(token0).approve(address(pancakeRouter), amount0);
        console.log("Token0 approved for router");

        // Prepare swap path
        address[] memory path = new address[](2);
        path[0] = token0;
        path[1] = token1;

        // Execute swap
        uint256[] memory amounts = IPancakeV2Router(address(pancakeRouter))
            .swapExactTokensForTokens(
                amount0,
                0, // amountOutMin (slippage protection can be set)
                path,
                userAddress,
                block.timestamp + 300 // Expires in 5 minutes
            );

        console.log("Swap executed successfully");
        console.log("Amount in:", amounts[0]);
        console.log("Amount out:", amounts[1]);

        vm.stopBroadcast();
    }

    function bindRootInviter(address inviter, address invitee) internal {
        console.log("--- Bind Inviter Test ---");
        console.log("User:", invitee);
        console.log("Inviter:", deployerPrivateKey, inviter);

        vm.startBroadcast(deployerPrivateKey);
        nodeManager.bindRootInviter(inviter, invitee);
        vm.stopBroadcast();
    }

    /**
     * @dev Bind inviter
     * @param userPrivateKey User private key
     * @param inviterAddress Inviter address
     */
    function bindInviter(uint256 userPrivateKey, address inviterAddress) internal {
        address userAddress = vm.rememberKey(userPrivateKey);

        console.log("--- Bind Inviter Test ---");
        console.log("User:", userAddress);
        console.log("Inviter:", inviterAddress);

        vm.startBroadcast(userPrivateKey);

        if (nodeManager.inviters(userAddress) == address(0)) {
            nodeManager.bindInviter(inviterAddress);
            console.log("Successfully bound inviter");
        } else {
            console.log("Inviter already set, skipping");
        }

        vm.stopBroadcast();
    }

    /**
     * @dev Purchase node
     * @param userPrivateKey User private key
     * @param nodeAmount Node amount (USDT)
     */
    function purchaseNode(uint256 userPrivateKey, uint256 nodeAmount) internal {
        address userAddress = vm.rememberKey(userPrivateKey);

        console.log("--- Purchase Node Test ---");
        console.log("User:", userAddress);
        console.log("Node Amount:", nodeAmount / usdtDecimals, "USDT");

        vm.startBroadcast(userPrivateKey);

        uint256 userUsdtBalance = usdt.balanceOf(userAddress);
        require(userUsdtBalance >= nodeAmount, "Insufficient USDT balance for node purchase");

        usdt.approve(address(nodeManager), nodeAmount);
        nodeManager.purchaseNode(nodeAmount);
        console.log("Node purchased successfully");

        vm.stopBroadcast();
    }

    /**
     * @dev Distribute node rewards
     * @param operatorPrivateKey Operator private key (requires distributeRewardManager permission)
     * @param recipient Recipient address
     * @param tokenAmount Reward amount (CMT)
     * @param usdtAmount Reward amount (USDT)
     * @param incomeType Income type (0 - Node income, 1 - Promotion income)
     */
    function distributeNodeRewards(
        uint256 operatorPrivateKey,
        address recipient,
        uint256 tokenAmount,
        uint256 usdtAmount,
        uint8 incomeType
    ) internal {
        console.log("--- Distribute Node Rewards Test ---");
        console.log("Recipient:", recipient);
        console.log("Reward Amount:", tokenAmount / cmtDecimals, "CMT");
        console.log("Income Type:", incomeType);

        vm.startBroadcast(operatorPrivateKey);

        nodeManager.distributeRewards(recipient, tokenAmount, usdtAmount, incomeType);
        console.log("Rewards distributed successfully");

        vm.stopBroadcast();
    }

    /**
     * @dev Claim node reward
     * @param userPrivateKey User private key
     * @param claimAmount 领取金额（CMT）
     */
    function claimNodeReward(uint256 userPrivateKey, uint256 claimAmount) internal {
        address userAddress = vm.rememberKey(userPrivateKey);

        console.log("--- Claim Node Reward Test ---");
        console.log("User:", userAddress);
        console.log("Claim Amount:", claimAmount / cmtDecimals, "CMT");

        vm.startBroadcast(userPrivateKey);

        nodeManager.claimReward(claimAmount);
        console.log("Rewards claimed successfully");

        vm.stopBroadcast();
    }

    /**
     * @dev 添加流动性到 PancakeSwap（通过 NodeManager）
     * @param operatorPrivateKey 操作员私钥（需要有 distributeRewardManager 权限）
     * @param liquidityAmount 流动性金额（USDT）
     */
    function addLiquidityViaNode(uint256 operatorPrivateKey, uint256 liquidityAmount) internal {
        address operatorAddress = vm.rememberKey(operatorPrivateKey);

        console.log("--- Add Liquidity Test (NodeManager) ---");
        console.log("Operator:", operatorAddress);
        console.log("Liquidity Amount:", liquidityAmount / usdtDecimals, "USDT");

        vm.startBroadcast(operatorPrivateKey);

        uint256 usdtBalance = usdt.balanceOf(address(nodeManager));
        require(usdtBalance >= liquidityAmount, "Insufficient USDT balance for liquidity");

        nodeManager.addLiquidity(liquidityAmount, liquidityAmount, operatorAddress);
        console.log("Liquidity added successfully");

        vm.stopBroadcast();
    }

    /**
     * @dev 添加流动性到 PancakeSwap（通过 StakingManager）
     * @param operatorPrivateKey 操作员私钥（需要有 stakingOperatorManager 权限）
     * @param liquidityAmount 流动性金额（USDT）
     */
    function addLiquidityViaStaking(uint256 operatorPrivateKey, uint256 liquidityAmount) internal {
        address operatorAddress = vm.rememberKey(operatorPrivateKey);

        console.log("--- Add Liquidity Test (StakingManager) ---");
        console.log("Operator:", operatorAddress);
        console.log("Liquidity Amount:", liquidityAmount / usdtDecimals, "USDT");

        vm.startBroadcast(operatorPrivateKey);

        uint256 usdtBalance = usdt.balanceOf(address(stakingManager));
        require(usdtBalance >= liquidityAmount, "Insufficient USDT balance for liquidity");

        stakingManager.addLiquidity(liquidityAmount, 1e18, 0);
        console.log("Liquidity added successfully");

        vm.stopBroadcast();
    }

    /**
     * @dev 流动性提供者质押存款
     * @param userPrivateKey 用户私钥
     * @param stakingAmount 质押金额（USDT，必须是 T1-T6 之一）
     */
    function liquidityProviderDeposit(uint256 userPrivateKey, uint256 stakingAmount) internal {
        address userAddress = vm.rememberKey(userPrivateKey);

        console.log("--- Liquidity Provider Deposit Test ---");
        console.log("User:", userAddress);
        console.log("Staking Amount:", stakingAmount / usdtDecimals, "USDT");

        vm.startBroadcast(userPrivateKey);

        uint256 userUsdtBalance = usdt.balanceOf(userAddress);
        require(userUsdtBalance >= stakingAmount, "Insufficient USDT balance for staking");

        usdt.approve(address(stakingManager), stakingAmount);
        stakingManager.liquidityProviderDeposit(stakingAmount);
        console.log("Liquidity provider deposit successful");

        vm.stopBroadcast();
    }

    /**
     * @dev 创建流动性提供者奖励
     * @param operatorPrivateKey 操作员私钥（需要有 stakingOperatorManager 权限）
     * @param lpAddress 流动性提供者地址
     * @param rewardAmount 奖励金额（CMT）
     * @param incomeType 收益类型（0-每日收益, 1-直推奖励, 2-团队奖励, 3-FOMO池奖励）
     */
    function createLiquidityProviderReward(
        uint256 operatorPrivateKey,
        address lpAddress,
        uint256 rewardAmount,
        uint8 incomeType
    ) internal {
        console.log("--- Create Liquidity Provider Reward Test ---");
        console.log("LP Address:", lpAddress);
        console.log("Reward Amount:", rewardAmount / cmtDecimals, "CMT");
        console.log("Income Type:", incomeType);

        vm.startBroadcast(operatorPrivateKey);

        stakingManager.createLiquidityProviderReward(lpAddress, 0, rewardAmount, rewardAmount, incomeType);
        console.log("Liquidity provider reward created successfully");

        vm.stopBroadcast();
    }

    /**
     * @dev 流动性提供者领取奖励
     * @param userPrivateKey 用户私钥
     * @param claimAmount 领取金额（CMT）
     */
    function liquidityProviderClaimReward(uint256 userPrivateKey, uint256 claimAmount) internal {
        address userAddress = vm.rememberKey(userPrivateKey);

        console.log("--- Liquidity Provider Claim Reward Test ---");
        console.log("User:", userAddress);
        console.log("Claim Amount:", claimAmount / cmtDecimals, "CMT");

        vm.startBroadcast(userPrivateKey);

        stakingManager.liquidityProviderClaimReward(0, claimAmount);
        console.log("Liquidity provider reward claimed successfully");

        vm.stopBroadcast();
    }

    /**
     * @dev 交换 USDT 为底层代币并销毁
     * @param operatorPrivateKey 操作员私钥（需要有 stakingOperatorManager 权限）
     * @param swapAmount USDT 交换金额
     * @param subTokenAmount 转给 subTokenFundingManager 的 USDT 金额
     */
    function swapBurn(uint256 operatorPrivateKey, uint256 swapAmount, uint256 subTokenAmount) internal {
        address operatorAddress = vm.rememberKey(operatorPrivateKey);

        console.log("--- Swap and Burn Test ---");
        console.log("Operator:", operatorAddress);
        console.log("Swap Amount:", swapAmount / usdtDecimals, "USDT");
        console.log("SubToken Amount:", subTokenAmount / usdtDecimals, "USDT");

        vm.startBroadcast(operatorPrivateKey);

        uint256 usdtBalance = usdt.balanceOf(address(stakingManager));
        require(usdtBalance >= swapAmount + subTokenAmount, "Insufficient USDT balance in StakingManager");

        stakingManager.swapBurn(swapAmount, subTokenAmount);
        console.log("Swap and burn executed successfully");

        vm.stopBroadcast();
    }

    /**
     * @dev 流动性提供者完整流程集成测试
     */
    function integratedLiquidityProviderTest() internal {
        address user2Address = vm.rememberKey(user2PrivateKey);
        address deployerAddress = vm.rememberKey(deployerPrivateKey);

        console.log("=== Starting Integrated Liquidity Provider Test ===");

        // 1. 确保用户已绑定邀请人
        if (nodeManager.inviters(user2Address) == address(0)) {
            bindInviter(user2PrivateKey, deployerAddress);
        }

        // 2. 流动性提供者质押（T1级别: 100 USDT）
        uint256 t1Amount = 100 * usdtDecimals;
        liquidityProviderDeposit(user2PrivateKey, t1Amount);

        // 3. 创建流动性提供者奖励（需要 stakingOperatorManager 权限）
        // createLiquidityProviderReward(deployerPrivateKey, user2Address, 5 * cmtDecimals, 0);

        // 4. 领取奖励
        // liquidityProviderClaimReward(user2PrivateKey, 2 * cmtDecimals);

        // 5. 交换并销毁代币
        // swapBurn(deployerPrivateKey, 100 * usdtDecimals, 10 * usdtDecimals);

        console.log("=== Integrated Liquidity Provider Test Completed ===");
    }
}
