// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/event/core/AdminFeeVault.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./MockERC20.sol";

contract TestAdminFeeVault is Test {
    AdminFeeVault private adminFeeVault;
    MockERC20 private token;

    address private owner = address(0x1);
    address private user = address(0x2);
    address private recipient = address(0x3);

    uint8 private constant FEE_TYPE = 1;

    function setUp() public {
        AdminFeeVault logic = new AdminFeeVault();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), owner, "");
        adminFeeVault = AdminFeeVault(payable(address(proxy)));
        vm.prank(owner);
        adminFeeVault.initialize(owner);

        token = new MockERC20("Mock USDT", "USDT");
        token.mint(user, 1_000_000 ether);

        vm.deal(user, 100 ether);
    }

    function testInitializeRevertsWithZeroAddress() public {
        AdminFeeVault logic = new AdminFeeVault();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), owner, "");
        AdminFeeVault vault = AdminFeeVault(payable(address(proxy)));
        vm.expectRevert(AdminFeeVault.InvalidAddress.selector);
        vault.initialize(address(0));
    }

    function testReceiveFeeERC20() public {
        uint256 amount = 1000 ether;

        vm.startPrank(user);
        token.approve(address(adminFeeVault), amount);
        adminFeeVault.receiveFee(address(token), amount, FEE_TYPE, amount);
        vm.stopPrank();

        assertEq(adminFeeVault.getTokenBalance(address(token)), amount, "token balance should update");
        assertEq(adminFeeVault.getFeeBalance(address(token), FEE_TYPE), amount, "fee balance should update");
        assertEq(token.balanceOf(address(adminFeeVault)), amount, "vault should hold tokens");
    }

    function testReceiveFeeETH() public {
        uint256 amount = 5 ether;

        vm.prank(user);
        adminFeeVault.receiveFee{value: amount}(adminFeeVault.ETHAddress(), amount, FEE_TYPE, amount);

        assertEq(adminFeeVault.getTokenBalance(adminFeeVault.ETHAddress()), amount, "eth balance should update");
        assertEq(adminFeeVault.getFeeBalance(adminFeeVault.ETHAddress(), FEE_TYPE), amount, "fee balance should update");
        assertEq(address(adminFeeVault).balance, amount, "vault should hold ETH");
    }

    function testReceiveFeeRevertsOnInvalidAmount() public {
        vm.expectRevert(AdminFeeVault.InvalidAmount.selector);
        adminFeeVault.receiveFee(address(token), 0, FEE_TYPE, 0);
    }

    function testReceiveFeeRevertsOnEthValueMismatch() public {
        address ethAddress = adminFeeVault.ETHAddress();
        vm.prank(user);
        vm.expectRevert(AdminFeeVault.InvalidAmount.selector);
        adminFeeVault.receiveFee{value: 1 ether}(ethAddress, 2 ether, FEE_TYPE, 2 ether);
    }

    function testWithdrawERC20() public {
        uint256 amount = 1000 ether;

        vm.startPrank(user);
        token.approve(address(adminFeeVault), amount);
        adminFeeVault.receiveFee(address(token), amount, FEE_TYPE, amount);
        vm.stopPrank();

        vm.prank(owner);
        adminFeeVault.withdraw(address(token), recipient, 400 ether);

        assertEq(token.balanceOf(recipient), 400 ether, "recipient should receive tokens");
        assertEq(adminFeeVault.getTokenBalance(address(token)), 600 ether, "balance should decrease");
    }

    function testWithdrawETH() public {
        uint256 amount = 3 ether;

        address ethAddress = adminFeeVault.ETHAddress();

        vm.prank(user);
        adminFeeVault.receiveFee{value: amount}(ethAddress, amount, FEE_TYPE, amount);

        uint256 recipientBefore = recipient.balance;
        vm.prank(owner);
        adminFeeVault.withdraw(ethAddress, recipient, 1 ether);

        assertEq(recipient.balance, recipientBefore + 1 ether, "recipient should receive ETH");
        assertEq(adminFeeVault.getTokenBalance(adminFeeVault.ETHAddress()), 2 ether, "balance should decrease");
    }

    function testWithdrawRevertsWhenNotOwner() public {
        vm.expectRevert();
        adminFeeVault.withdraw(address(token), recipient, 1 ether);
    }

    function testPauseBlocksReceiveAndWithdraw() public {
        uint256 amount = 1 ether;

        vm.prank(owner);
        adminFeeVault.pause();

        vm.startPrank(user);
        token.approve(address(adminFeeVault), amount);
        vm.expectRevert();
        adminFeeVault.receiveFee(address(token), amount, FEE_TYPE, amount);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert();
        adminFeeVault.withdraw(address(token), recipient, amount);

        vm.prank(owner);
        adminFeeVault.unpause();
    }
}
