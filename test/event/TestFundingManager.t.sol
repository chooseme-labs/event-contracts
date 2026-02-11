// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/event/core/FundingManager.sol";
import "../../src/event/pod/FundingPod.sol";
import "../../src/event/pod/FeeVaultPod.sol";
import "../../src/event/core/AdminFeeVault.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./MockERC20.sol";

contract TestFundingManager is Test {
    FundingManager private manager;
    FundingPod private fundingPod;
    FeeVaultPod private feeVaultPod;
    AdminFeeVault private adminFeeVault;
    MockERC20 private token;

    address private owner = address(0x1);
    address private authorized = address(0x2);
    address private user = address(0x3);
    address private recipient = address(0x4);

    function setUp() public {
        FundingManager managerLogic = new FundingManager();
        TransparentUpgradeableProxy managerProxy = new TransparentUpgradeableProxy(address(managerLogic), owner, "");
        manager = FundingManager(payable(address(managerProxy)));
        vm.prank(owner);
        manager.initialize(owner);

        FundingPod podLogic = new FundingPod();
        TransparentUpgradeableProxy podProxy = new TransparentUpgradeableProxy(address(podLogic), owner, "");
        fundingPod = FundingPod(payable(address(podProxy)));
        vm.prank(owner);
        fundingPod.initialize(owner, address(manager));

        AdminFeeVault vaultLogic = new AdminFeeVault();
        TransparentUpgradeableProxy vaultProxy = new TransparentUpgradeableProxy(address(vaultLogic), owner, "");
        adminFeeVault = AdminFeeVault(payable(address(vaultProxy)));
        vm.prank(owner);
        adminFeeVault.initialize(owner);

        FeeVaultPod feePodLogic = new FeeVaultPod();
        TransparentUpgradeableProxy feePodProxy = new TransparentUpgradeableProxy(address(feePodLogic), owner, "");
        feeVaultPod = FeeVaultPod(payable(address(feePodProxy)));
        vm.prank(owner);
        feeVaultPod.initialize(owner, address(0x99), address(0x98), address(adminFeeVault), 0);

        token = new MockERC20("Mock USDT", "USDT");
        token.mint(user, 1_000_000 ether);

        vm.deal(user, 100 ether);

        vm.prank(owner);
        manager.addPod(address(fundingPod));
    }

    function testInitializeRevertsWithInvalidAddress() public {
        FundingManager mLogic = new FundingManager();
        TransparentUpgradeableProxy mProxy = new TransparentUpgradeableProxy(address(mLogic), owner, "");
        FundingManager m = FundingManager(payable(address(mProxy)));
        vm.expectRevert(FundingManager.InvalidAddress.selector);
        m.initialize(address(0));
    }

    function testAddSupportTokenThroughManager() public {
        vm.prank(owner);
        manager.addSupportToken(address(fundingPod), address(token));

        assertTrue(fundingPod.isSupportToken(address(token)), "token should be supported");
    }

    function testRemoveSupportTokenThroughManager() public {
        vm.startPrank(owner);
        manager.addSupportToken(address(fundingPod), address(token));
        manager.removeSupportToken(address(fundingPod), address(token));
        vm.stopPrank();

        assertFalse(fundingPod.isSupportToken(address(token)), "token should be removed");
    }

    function testSetFeeVaultPodThroughManager() public {
        vm.prank(owner);
        manager.setFeeVaultPod(address(fundingPod), address(feeVaultPod));

        assertEq(fundingPod.feeVaultPod(), address(feeVaultPod), "fee vault pod should be set");
    }

    function testAuthorizedCallerManagement() public {
        vm.prank(owner);
        manager.addAuthorizedCaller(authorized);
        assertTrue(manager.isAuthorizedCaller(authorized), "caller should be authorized");

        vm.prank(owner);
        manager.removeAuthorizedCaller(authorized);
        assertFalse(manager.isAuthorizedCaller(authorized), "caller should be removed");
    }

    function testWithdrawForUserOnlyAuthorizedCaller() public {
        vm.startPrank(owner);
        manager.addSupportToken(address(fundingPod), address(token));
        manager.addAuthorizedCaller(authorized);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(fundingPod), 500 ether);
        fundingPod.deposit(address(token), 500 ether);
        vm.stopPrank();

        vm.prank(authorized);
        manager.withdrawForUser(address(fundingPod), recipient, address(token), 200 ether);

        assertEq(token.balanceOf(recipient), 200 ether, "recipient should receive tokens");
    }

    function testCollectWinFeeOnlyAuthorizedCaller() public {
        vm.startPrank(owner);
        manager.addSupportToken(address(fundingPod), address(token));
        manager.setFeeVaultPod(address(fundingPod), address(feeVaultPod));
        manager.addAuthorizedCaller(authorized);
        vm.stopPrank();

        vm.startPrank(user);
        token.approve(address(fundingPod), 500 ether);
        fundingPod.deposit(address(token), 500 ether);
        vm.stopPrank();

        vm.prank(authorized);
        manager.collectWinFee(address(fundingPod), address(token), 200 ether, 1);

        assertEq(feeVaultPod.getTokenBalance(address(token)), 200 ether, "fee vault should receive fee");
    }

    function testOnlyAuthorizedCallerGuard() public {
        vm.prank(owner);
        manager.addSupportToken(address(fundingPod), address(token));

        vm.prank(user);
        vm.expectRevert(FundingManager.OnlyAuthorizedCaller.selector);
        manager.withdrawForUser(address(fundingPod), recipient, address(token), 1 ether);
    }
}
