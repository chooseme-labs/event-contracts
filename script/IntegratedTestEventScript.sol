// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AdminFeeVault} from "../src/event/core/AdminFeeVault.sol";
import {FeeVaultManager} from "../src/event/core/FeeVaultManager.sol";
import {FundingManager} from "../src/event/core/FundingManager.sol";
import {FeeVaultPod} from "../src/event/pod/FeeVaultPod.sol";
import {FundingPod} from "../src/event/pod/FundingPod.sol";
import {MockERC20} from "./MockERC20.sol";

import "./EnvContract.sol";

/**
 * @title IntegratedTestEventScript
 * @notice Integrated test script for event-related contracts
 * @dev Run with: forge script IntegratedTestEventScript --rpc-url <RPC> --broadcast -vvvv
 */
// MODE=1 forge script IntegratedTestEventScript --sig "run()"  --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast
contract IntegratedTestEventScript is Script, EnvContract {
    AdminFeeVault public adminFeeVault;
    FeeVaultManager public feeVaultManager;
    FundingManager public fundingManager;
    FeeVaultPod public feeVaultPod;
    FundingPod public fundingPod;
    MockERC20 public mockERC20;

    uint256 public deployerPrivateKey;
    address public owner;

    address public user1;
    address public user2;
    uint256 public user1PrivateKey;
    uint256 public user2PrivateKey;

    function run() public {
        console.log("=== Starting Integrated Event Tests ===");

        deployerPrivateKey = getCurPrivateKey();
        owner = vm.addr(deployerPrivateKey);

        (
            address proxyAdminFeeVault,
            address proxyFeeVaultManager,
            address proxyFundingManager,
            address proxyFeeVaultPod,
            address proxyFundingPod,
            address mockERC20Address
        ) = getEventAddresses();

        require(proxyAdminFeeVault != address(0), "proxyAdminFeeVault not found");
        require(proxyFeeVaultManager != address(0), "proxyFeeVaultManager not found");
        require(proxyFundingManager != address(0), "proxyFundingManager not found");
        require(proxyFeeVaultPod != address(0), "proxyFeeVaultPod not found");
        require(proxyFundingPod != address(0), "proxyFundingPod not found");

        adminFeeVault = AdminFeeVault(payable(proxyAdminFeeVault));
        feeVaultManager = FeeVaultManager(payable(proxyFeeVaultManager));
        fundingManager = FundingManager(payable(proxyFundingManager));
        feeVaultPod = FeeVaultPod(payable(proxyFeeVaultPod));
        fundingPod = FundingPod(payable(proxyFundingPod));

        if (mockERC20Address != address(0)) {
            mockERC20 = MockERC20(mockERC20Address);
        }

        setupTestAccounts();

        vm.startBroadcast(deployerPrivateKey);
        fundingManager.addAuthorizedCaller(owner);

        if (address(mockERC20) != address(0)) {
            fundingManager.addSupportToken(address(fundingPod), address(mockERC20));
        }
        fundingManager.addSupportToken(address(fundingPod), fundingPod.ETHAddress());
        vm.stopBroadcast();

        if (address(mockERC20) != address(0)) {
            testERC20Flow();
        }
        testETHFlow();
        // testWithdrawFlow();

        console.log("=== All Integrated Event Tests Completed ===");
        // require(false, "End of Integrated Test Script");
    }

    function setupTestAccounts() internal {
        uint256 mode = vm.envUint("MODE");
        if (mode == 0) {
            string memory mnemonic = vm.envString("DEV_MNEMONIC");
            user1PrivateKey = vm.deriveKey(mnemonic, 1);
            user2PrivateKey = vm.deriveKey(mnemonic, 2);
        } else {
            user1PrivateKey = deployerPrivateKey;
            user2PrivateKey = deployerPrivateKey;
        }
        user1 = vm.addr(user1PrivateKey);
        user2 = vm.addr(user2PrivateKey);
    }

    function testERC20Flow() internal {
        console.log("\n=== Test 1: ERC20 Deposit & Win Fee ===");

        uint256 depositAmount = 1000 ether;
        uint256 feeAmount = 200 ether;

        vm.startBroadcast(deployerPrivateKey);
        mockERC20.mint(user1, depositAmount);
        vm.stopBroadcast();

        vm.startBroadcast(user1PrivateKey);
        mockERC20.approve(address(fundingPod), depositAmount);
        fundingPod.deposit(address(mockERC20), depositAmount);
        vm.stopBroadcast();

        uint256 podBalance = mockERC20.balanceOf(address(fundingPod));
        require(podBalance >= depositAmount, "fundingPod ERC20 balance mismatch");

        vm.startBroadcast(deployerPrivateKey);
        fundingManager.collectWinFee(address(fundingPod), address(mockERC20), feeAmount, 1);
        vm.stopBroadcast();

        uint256 adminFeeRate = feeVaultPod.adminFeeRate();
        uint256 expectedAdmin = (feeAmount * adminFeeRate) / feeVaultPod.FEE_DENOMINATOR();
        uint256 expectedRemaining = feeAmount - expectedAdmin;

        require(
            feeVaultPod.getTokenBalance(address(mockERC20)) >= expectedRemaining, "feeVaultPod fee balance mismatch"
        );
        require(
            adminFeeVault.getTokenBalance(address(mockERC20)) >= expectedAdmin, "adminFeeVault fee balance mismatch"
        );
        console.log("ERC20 fee collected: remaining", expectedRemaining, "admin", expectedAdmin);
    }

    function testETHFlow() internal {
        console.log("\n=== Test 2: ETH Deposit ===");

        uint256 ethDeposit = 1 ether;
        vm.deal(user1, ethDeposit);

        vm.startBroadcast(user1PrivateKey);
        fundingPod.deposit{value: ethDeposit}(fundingPod.ETHAddress(), ethDeposit);
        vm.stopBroadcast();

        require(address(fundingPod).balance >= ethDeposit, "fundingPod ETH balance mismatch");
    }

    function testWithdrawFlow() internal {
        console.log("\n=== Test 3: Withdraw Flows ===");

        if (address(mockERC20) != address(0)) {
            uint256 withdrawAmount = 50 ether;
            vm.startBroadcast(deployerPrivateKey);
            feeVaultPod.withdraw(address(mockERC20), user2, withdrawAmount);
            adminFeeVault.withdraw(address(mockERC20), user2, withdrawAmount / 2);
            vm.stopBroadcast();

            uint256 user2Balance = mockERC20.balanceOf(user2);
            require(user2Balance >= withdrawAmount / 2, "user2 ERC20 withdraw failed");
        }

        uint256 ethWithdraw = 0.2 ether;
        if (address(fundingPod).balance >= ethWithdraw) {
            vm.startBroadcast(deployerPrivateKey);
            fundingManager.withdrawForUser(address(fundingPod), user2, fundingPod.ETHAddress(), ethWithdraw);
            vm.stopBroadcast();
        }

        console.log("Withdraw flows executed");
    }
}
