// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/event/pod/FeeVaultPod.sol";
import "../../src/event/core/AdminFeeVault.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./MockERC20.sol";

contract TestFeeVaultPod is Test {
    FeeVaultPod private feeVaultPod;
    AdminFeeVault private adminFeeVault;
    MockERC20 private token;

    address private owner = address(0x1);
    address private feeVaultManager = address(0x2);
    address private withdrawManager = address(0x3);
    address private user = address(0x4);
    address private recipient = address(0x5);

    uint8 private constant FEE_TYPE = 2;
    uint256 private constant ADMIN_FEE_RATE = 1000; // 10%

    function setUp() public {
        AdminFeeVault vaultLogic = new AdminFeeVault();
        TransparentUpgradeableProxy vaultProxy = new TransparentUpgradeableProxy(address(vaultLogic), owner, "");
        adminFeeVault = AdminFeeVault(payable(address(vaultProxy)));
        vm.prank(owner);
        adminFeeVault.initialize(owner);

        FeeVaultPod podLogic = new FeeVaultPod();
        TransparentUpgradeableProxy podProxy = new TransparentUpgradeableProxy(address(podLogic), owner, "");
        feeVaultPod = FeeVaultPod(payable(address(podProxy)));
        vm.prank(owner);
        feeVaultPod.initialize(owner, feeVaultManager, withdrawManager, address(adminFeeVault), ADMIN_FEE_RATE);

        token = new MockERC20("Mock USDT", "USDT");
        token.mint(user, 1_000_000 ether);

        vm.deal(user, 100 ether);
    }

    function testInitializeRevertsWithInvalidAddress() public {
        FeeVaultPod podLogic = new FeeVaultPod();
        TransparentUpgradeableProxy podProxy = new TransparentUpgradeableProxy(address(podLogic), owner, "");
        FeeVaultPod pod = FeeVaultPod(payable(address(podProxy)));
        vm.expectRevert(FeeVaultPod.InvalidAddress.selector);
        pod.initialize(address(0), feeVaultManager, withdrawManager, address(adminFeeVault), ADMIN_FEE_RATE);
    }

    function testInitializeRevertsWithInvalidFeeRate() public {
        FeeVaultPod podLogic = new FeeVaultPod();
        TransparentUpgradeableProxy podProxy = new TransparentUpgradeableProxy(address(podLogic), owner, "");
        FeeVaultPod pod = FeeVaultPod(payable(address(podProxy)));
        uint256 maxRate = pod.MAX_ADMIN_FEE_RATE();
        vm.expectRevert(FeeVaultPod.InvalidFeeRate.selector);
        pod.initialize(owner, feeVaultManager, withdrawManager, address(adminFeeVault), maxRate + 1);
    }

    function testReceiveFeeERC20WithAdminFee() public {
        uint256 amount = 1000 ether;
        uint256 expectedAdmin = (amount * ADMIN_FEE_RATE) / feeVaultPod.FEE_DENOMINATOR();
        uint256 expectedRemaining = amount - expectedAdmin;

        vm.startPrank(user);
        token.approve(address(feeVaultPod), amount);
        feeVaultPod.receiveFee(address(token), amount, FEE_TYPE, amount);
        vm.stopPrank();

        assertEq(feeVaultPod.getTokenBalance(address(token)), expectedRemaining, "pod balance should exclude admin fee");
        assertEq(feeVaultPod.getFeeBalance(address(token), FEE_TYPE), expectedRemaining, "fee balance should update");
        assertEq(token.balanceOf(address(feeVaultPod)), expectedRemaining, "pod should hold remaining fee");

        assertEq(adminFeeVault.getTokenBalance(address(token)), expectedAdmin, "admin vault should receive admin fee");
        assertEq(token.balanceOf(address(adminFeeVault)), expectedAdmin, "admin vault token balance should update");
    }

    function testReceiveFeeETHWithAdminFee() public {
        uint256 amount = 10 ether;
        uint256 expectedAdmin = (amount * ADMIN_FEE_RATE) / feeVaultPod.FEE_DENOMINATOR();
        uint256 expectedRemaining = amount - expectedAdmin;

        vm.prank(user);
        feeVaultPod.receiveFee{value: amount}(feeVaultPod.ETHAddress(), amount, FEE_TYPE, amount);

        assertEq(
            feeVaultPod.getTokenBalance(feeVaultPod.ETHAddress()), expectedRemaining, "pod ETH balance should update"
        );
        assertEq(address(feeVaultPod).balance, expectedRemaining, "pod should hold remaining ETH");
        assertEq(address(adminFeeVault).balance, expectedAdmin, "admin vault should receive ETH admin fee");
    }

    function testReceiveFeeRevertsOnInvalidAmounts() public {
        vm.expectRevert(FeeVaultPod.InvalidAmount.selector);
        feeVaultPod.receiveFee(address(token), 0, FEE_TYPE, 0);

        vm.expectRevert(FeeVaultPod.InvalidAmount.selector);
        feeVaultPod.receiveFee(address(token), 1 ether, FEE_TYPE, 2 ether);
    }

    function testWithdrawByOwner() public {
        uint256 amount = 1000 ether;

        vm.startPrank(user);
        token.approve(address(feeVaultPod), amount);
        feeVaultPod.receiveFee(address(token), amount, FEE_TYPE, amount);
        vm.stopPrank();

        vm.prank(owner);
        feeVaultPod.withdraw(address(token), recipient, 200 ether);

        assertEq(token.balanceOf(recipient), 200 ether, "recipient should receive tokens");
    }

    function testWithdrawByWithdrawManager() public {
        uint256 amount = 1000 ether;

        vm.startPrank(user);
        token.approve(address(feeVaultPod), amount);
        feeVaultPod.receiveFee(address(token), amount, FEE_TYPE, amount);
        vm.stopPrank();

        vm.prank(withdrawManager);
        feeVaultPod.withdraw(address(token), recipient, 150 ether);

        assertEq(token.balanceOf(recipient), 150 ether, "recipient should receive tokens");
    }

    function testWithdrawRevertsWhenNotAuthorized() public {
        vm.prank(user);
        vm.expectRevert(FeeVaultPod.OnlyOwnerOrWithdrawManager.selector);
        feeVaultPod.withdraw(address(token), recipient, 1 ether);
    }

    function testSetWithdrawManager() public {
        address newManager = address(0x99);

        vm.prank(owner);
        feeVaultPod.setWithdrawManager(newManager);

        assertEq(feeVaultPod.withdrawManager(), newManager, "withdraw manager should update");
    }

    function testSetAdminFeeVaultOnlyManager() public {
        address newVault = address(0x88);

        vm.prank(user);
        vm.expectRevert(FeeVaultPod.OnlyFeeVaultManager.selector);
        feeVaultPod.setAdminFeeVault(newVault);

        vm.prank(feeVaultManager);
        feeVaultPod.setAdminFeeVault(newVault);

        assertEq(feeVaultPod.adminFeeVault(), newVault, "admin fee vault should update");
    }

    function testSetAdminFeeRateOnlyManager() public {
        vm.prank(user);
        vm.expectRevert(FeeVaultPod.OnlyFeeVaultManager.selector);
        feeVaultPod.setAdminFeeRate(2000);

        vm.prank(feeVaultManager);
        feeVaultPod.setAdminFeeRate(2000);

        assertEq(feeVaultPod.adminFeeRate(), 2000, "admin fee rate should update");
    }

    function testPauseAndUnpauseOnlyManager() public {
        vm.prank(user);
        vm.expectRevert(FeeVaultPod.OnlyFeeVaultManager.selector);
        feeVaultPod.pause();

        vm.prank(feeVaultManager);
        feeVaultPod.pause();

        vm.startPrank(user);
        token.approve(address(feeVaultPod), 1 ether);
        vm.expectRevert();
        feeVaultPod.receiveFee(address(token), 1 ether, FEE_TYPE, 1 ether);
        vm.stopPrank();

        vm.prank(feeVaultManager);
        feeVaultPod.unpause();
    }
}
