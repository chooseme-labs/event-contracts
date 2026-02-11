// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/event/pod/FundingPod.sol";
import "../../src/event/pod/FeeVaultPod.sol";
import "../../src/event/core/AdminFeeVault.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./MockERC20.sol";

contract TestFundingPod is Test {
    FundingPod private fundingPod;
    FeeVaultPod private feeVaultPod;
    AdminFeeVault private adminFeeVault;
    MockERC20 private token;

    address private owner = address(0x1);
    address private fundingManager = address(0x1);
    address private user = address(0x3);
    address private recipient = address(0x4);

    function setUp() public {
        FundingPod podLogic = new FundingPod();
        TransparentUpgradeableProxy podProxy = new TransparentUpgradeableProxy(address(podLogic), owner, "");
        fundingPod = FundingPod(payable(address(podProxy)));
        vm.prank(owner);
        fundingPod.initialize(owner, fundingManager);
        fundingManager = fundingPod.fundingManager();

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

        vm.prank(fundingManager);
        fundingPod.addSupportToken(address(token));

        address ethAddress = fundingPod.ETHAddress();
        vm.prank(fundingManager);
        fundingPod.addSupportToken(ethAddress);
    }

    function testInitializeRevertsWithInvalidAddress() public {
        FundingPod podLogic = new FundingPod();
        TransparentUpgradeableProxy podProxy = new TransparentUpgradeableProxy(address(podLogic), owner, "");
        FundingPod pod = FundingPod(payable(address(podProxy)));
        vm.expectRevert(FundingPod.InvalidAddress.selector);
        pod.initialize(address(0), fundingManager);
    }

    function testAddAndRemoveSupportToken() public {
        address newToken = address(0x77);

        vm.prank(fundingManager);
        fundingPod.addSupportToken(newToken);
        assertTrue(fundingPod.isSupportToken(newToken), "token should be supported");

        vm.prank(fundingManager);
        fundingPod.removeSupportToken(newToken);
        assertFalse(fundingPod.isSupportToken(newToken), "token should be removed");
    }

    function testDepositERC20() public {
        uint256 amount = 500 ether;

        vm.startPrank(user);
        token.approve(address(fundingPod), amount);
        fundingPod.deposit(address(token), amount);
        vm.stopPrank();

        assertEq(token.balanceOf(address(fundingPod)), amount, "pod should hold tokens");
    }

    function testDepositETH() public {
        uint256 amount = 2 ether;

        address ethAddress = fundingPod.ETHAddress();
        vm.prank(user);
        fundingPod.deposit{value: amount}(ethAddress, amount);

        assertEq(address(fundingPod).balance, amount, "pod should hold ETH");
    }

    function testDepositRevertsWhenNotSupported() public {
        vm.prank(user);
        vm.expectRevert(FundingPod.TokenNotSupported.selector);
        fundingPod.deposit(address(0xdead), 1 ether);
    }

    function testWithdrawForUser() public {
        uint256 amount = 300 ether;

        vm.startPrank(user);
        token.approve(address(fundingPod), amount);
        fundingPod.deposit(address(token), amount);
        vm.stopPrank();

        vm.prank(fundingManager);
        fundingPod.withdrawForUser(recipient, address(token), 100 ether);

        assertEq(token.balanceOf(recipient), 100 ether, "recipient should receive tokens");
    }

    function testCollectWinFee() public {
        uint256 amount = 400 ether;

        vm.startPrank(user);
        token.approve(address(fundingPod), amount);
        fundingPod.deposit(address(token), amount);
        vm.stopPrank();

        vm.prank(fundingManager);
        fundingPod.setFeeVaultPod(address(feeVaultPod));

        vm.prank(fundingManager);
        fundingPod.collectWinFee(address(token), 200 ether, 1);

        assertEq(feeVaultPod.getTokenBalance(address(token)), 200 ether, "fee vault should receive fee");
    }

    function testCollectWinFeeRevertsWithoutFeeVaultPod() public {
        vm.prank(fundingManager);
        vm.expectRevert(FundingPod.InvalidAddress.selector);
        fundingPod.collectWinFee(address(token), 1 ether, 1);
    }

    function testOnlyFundingManagerGuards() public {
        vm.prank(user);
        vm.expectRevert(FundingPod.OnlyFundingManager.selector);
        fundingPod.addSupportToken(address(0x99));

        vm.prank(user);
        vm.expectRevert(FundingPod.OnlyFundingManager.selector);
        fundingPod.withdrawForUser(recipient, address(token), 1 ether);
    }
}
