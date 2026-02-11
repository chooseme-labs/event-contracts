// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/event/core/FeeVaultManager.sol";
import "../../src/event/core/AdminFeeVault.sol";
import "../../src/event/pod/FeeVaultPod.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./MockERC20.sol";

contract TestFeeVaultManager is Test {
    FeeVaultManager private manager;
    AdminFeeVault private adminFeeVault;
    FeeVaultPod private feeVaultPod;
    MockERC20 private token;

    address private owner = address(0x1);
    address private withdrawManager = address(0x2);
    address private user = address(0x3);

    function setUp() public {
        AdminFeeVault vaultLogic = new AdminFeeVault();
        TransparentUpgradeableProxy vaultProxy = new TransparentUpgradeableProxy(address(vaultLogic), owner, "");
        adminFeeVault = AdminFeeVault(payable(address(vaultProxy)));
        vm.prank(owner);
        adminFeeVault.initialize(owner);

        FeeVaultManager managerLogic = new FeeVaultManager();
        TransparentUpgradeableProxy managerProxy = new TransparentUpgradeableProxy(address(managerLogic), owner, "");
        manager = FeeVaultManager(payable(address(managerProxy)));
        vm.prank(owner);
        manager.initialize(owner, address(adminFeeVault));

        FeeVaultPod podLogic = new FeeVaultPod();
        TransparentUpgradeableProxy podProxy = new TransparentUpgradeableProxy(address(podLogic), owner, "");
        feeVaultPod = FeeVaultPod(payable(address(podProxy)));
        vm.prank(owner);
        feeVaultPod.initialize(owner, address(manager), withdrawManager, address(adminFeeVault), 500);

        token = new MockERC20("Mock USDT", "USDT");
        token.mint(user, 1_000_000 ether);

        vm.prank(owner);
        manager.addPod(address(feeVaultPod));
    }

    function testInitializeRevertsWithInvalidAddress() public {
        FeeVaultManager mLogic = new FeeVaultManager();
        TransparentUpgradeableProxy mProxy = new TransparentUpgradeableProxy(address(mLogic), owner, "");
        FeeVaultManager m = FeeVaultManager(payable(address(mProxy)));
        vm.expectRevert(FeeVaultManager.InvalidAddress.selector);
        m.initialize(address(0), address(adminFeeVault));
    }

    function testAddRemovePodAndGetPods() public {
        assertTrue(manager.isPod(address(feeVaultPod)), "pod should be whitelisted");

        vm.prank(owner);
        manager.removePod(address(feeVaultPod));

        assertFalse(manager.isPod(address(feeVaultPod)), "pod should be removed");
        address[] memory pods = manager.getPods();
        assertEq(pods.length, 0, "pods list should be empty");
    }

    function testSetAdminFeeVaultOnPod() public {
        address newVault = address(0x44);

        vm.prank(user);
        vm.expectRevert();
        manager.setAdminFeeVault(address(feeVaultPod), newVault);

        vm.prank(owner);
        manager.setAdminFeeVault(address(feeVaultPod), newVault);

        assertEq(feeVaultPod.adminFeeVault(), newVault, "pod admin fee vault should update");
    }

    function testSetAdminFeeRateOnPod() public {
        vm.prank(owner);
        manager.setAdminFeeRate(address(feeVaultPod), 1500);

        assertEq(feeVaultPod.adminFeeRate(), 1500, "pod admin fee rate should update");
    }

    function testSetGlobalAdminFeeVault() public {
        address newVault = address(0x99);

        vm.prank(owner);
        manager.setGlobalAdminFeeVault(newVault);

        assertEq(manager.adminFeeVault(), newVault, "global admin fee vault should update");
    }

    function testPauseAndUnpausePod() public {
        vm.prank(owner);
        manager.pausePod(address(feeVaultPod));

        vm.startPrank(user);
        token.approve(address(feeVaultPod), 1 ether);
        vm.expectRevert();
        feeVaultPod.receiveFee(address(token), 1 ether, 1, 1 ether);
        vm.stopPrank();

        vm.prank(owner);
        manager.unpausePod(address(feeVaultPod));
    }
}
