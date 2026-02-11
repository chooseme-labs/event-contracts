// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {EmptyContract} from "../src/utils/EmptyContract.sol";
import {AdminFeeVault} from "../src/event/core/AdminFeeVault.sol";
import {FeeVaultManager} from "../src/event/core/FeeVaultManager.sol";
import {FundingManager} from "../src/event/core/FundingManager.sol";
import {FeeVaultPod} from "../src/event/pod/FeeVaultPod.sol";
import {FundingPod} from "../src/event/pod/FundingPod.sol";
import {MockERC20} from "./MockERC20.sol";

import "./EnvContract.sol";

// MODE=1 forge script DepolyEventScript --sig "deploy()" --slow --multi --rpc-url <RPC> --broadcast
contract DepolyEventScript is Script, EnvContract {
    EmptyContract public emptyContract;

    ProxyAdmin public adminFeeVaultProxyAdmin;
    ProxyAdmin public feeVaultManagerProxyAdmin;
    ProxyAdmin public fundingManagerProxyAdmin;
    ProxyAdmin public feeVaultPodProxyAdmin;
    ProxyAdmin public fundingPodProxyAdmin;

    AdminFeeVault public adminFeeVaultImplementation;
    AdminFeeVault public adminFeeVault;

    FeeVaultManager public feeVaultManagerImplementation;
    FeeVaultManager public feeVaultManager;

    FundingManager public fundingManagerImplementation;
    FundingManager public fundingManager;

    FeeVaultPod public feeVaultPodImplementation;
    FeeVaultPod public feeVaultPod;

    FundingPod public fundingPodImplementation;
    FundingPod public fundingPod;

    MockERC20 public mockERC20;

    uint256 public deployerPrivateKey;

    // MODE=1 forge script DepolyEventScript --sig "deploy()"  --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast --verify --etherscan-api-key I4C1AKJT8J9KJVCXHZKK317T3XV8IVASRX
    function deploy() public {
        (
            address deployerAddress,
            address owner,
            address withdrawManager,
            uint256 adminFeeRate,
            address authorizedCaller
        ) = getEventENV();

        vm.startBroadcast(deployerPrivateKey);

        emptyContract = new EmptyContract();

        mockERC20 = new MockERC20("Mock USDT", "mUSDT");
        mockERC20.mint(deployerAddress, 100_000_000 ether);

        TransparentUpgradeableProxy proxyAdminFeeVault =
            new TransparentUpgradeableProxy(address(emptyContract), owner, "");
        adminFeeVault = AdminFeeVault(payable(address(proxyAdminFeeVault)));
        adminFeeVaultImplementation = new AdminFeeVault();
        adminFeeVaultProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyAdminFeeVault)));

        TransparentUpgradeableProxy proxyFeeVaultManager =
            new TransparentUpgradeableProxy(address(emptyContract), owner, "");
        feeVaultManager = FeeVaultManager(payable(address(proxyFeeVaultManager)));
        feeVaultManagerImplementation = new FeeVaultManager();
        feeVaultManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyFeeVaultManager)));

        TransparentUpgradeableProxy proxyFundingManager =
            new TransparentUpgradeableProxy(address(emptyContract), owner, "");
        fundingManager = FundingManager(payable(address(proxyFundingManager)));
        fundingManagerImplementation = new FundingManager();
        fundingManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyFundingManager)));

        TransparentUpgradeableProxy proxyFeeVaultPod =
            new TransparentUpgradeableProxy(address(emptyContract), owner, "");
        feeVaultPod = FeeVaultPod(payable(address(proxyFeeVaultPod)));
        feeVaultPodImplementation = new FeeVaultPod();
        feeVaultPodProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyFeeVaultPod)));

        TransparentUpgradeableProxy proxyFundingPod = new TransparentUpgradeableProxy(address(emptyContract), owner, "");
        fundingPod = FundingPod(payable(address(proxyFundingPod)));
        fundingPodImplementation = new FundingPod();
        fundingPodProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyFundingPod)));

        adminFeeVaultProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(adminFeeVault)),
            address(adminFeeVaultImplementation),
            abi.encodeWithSelector(AdminFeeVault.initialize.selector, owner)
        );

        feeVaultManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(feeVaultManager)),
            address(feeVaultManagerImplementation),
            abi.encodeWithSelector(FeeVaultManager.initialize.selector, owner, address(adminFeeVault))
        );

        fundingManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(fundingManager)),
            address(fundingManagerImplementation),
            abi.encodeWithSelector(FundingManager.initialize.selector, owner)
        );

        feeVaultPodProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(feeVaultPod)),
            address(feeVaultPodImplementation),
            abi.encodeWithSelector(
                FeeVaultPod.initialize.selector,
                owner,
                address(feeVaultManager),
                withdrawManager,
                address(adminFeeVault),
                adminFeeRate
            )
        );

        fundingPodProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(fundingPod)),
            address(fundingPodImplementation),
            abi.encodeWithSelector(FundingPod.initialize.selector, owner, address(fundingManager))
        );

        feeVaultManager.addPod(address(feeVaultPod));
        fundingManager.addPod(address(fundingPod));
        fundingManager.setFeeVaultPod(address(fundingPod), address(feeVaultPod));

        fundingManager.addSupportToken(address(fundingPod), fundingPod.ETHAddress());
        fundingManager.addSupportToken(address(fundingPod), address(mockERC20));

        if (authorizedCaller != address(0)) {
            fundingManager.addAuthorizedCaller(authorizedCaller);
        }

        vm.stopBroadcast();

        console.log("deployer:", deployerAddress);
        console.log("proxyAdminFeeVault:", address(proxyAdminFeeVault));
        console.log("proxyFeeVaultManager:", address(proxyFeeVaultManager));
        console.log("proxyFundingManager:", address(proxyFundingManager));
        console.log("proxyFeeVaultPod:", address(proxyFeeVaultPod));
        console.log("proxyFundingPod:", address(proxyFundingPod));
        console.log("mockERC20:", address(mockERC20));

        string memory obj = "{}";
        vm.serializeAddress(obj, "proxyAdminFeeVault", address(proxyAdminFeeVault));
        vm.serializeAddress(obj, "proxyFeeVaultManager", address(proxyFeeVaultManager));
        vm.serializeAddress(obj, "proxyFundingManager", address(proxyFundingManager));
        vm.serializeAddress(obj, "proxyFeeVaultPod", address(proxyFeeVaultPod));
        vm.serializeAddress(obj, "mockERC20", address(mockERC20));
        string memory finalJSON = vm.serializeAddress(obj, "proxyFundingPod", address(proxyFundingPod));
        vm.writeJson(finalJSON, getDeployPath2());
    }

    function getDeployPath2() public view returns (string memory) {
        uint256 mode = vm.envUint("MODE");
        if (mode == 0) {
            return string(abi.encodePacked("./cache/__deployed_addresses_event_dev", ".json"));
        } else {
            return string(abi.encodePacked("./cache/__deployed_addresses_event_prod", ".json"));
        }
    }

    function _getCurPrivateKey() public returns (uint256) {
        deployerPrivateKey = super.getCurPrivateKey();
    }

    function getEventENV()
        public
        returns (
            address deployerAddress,
            address owner,
            address withdrawManager,
            uint256 adminFeeRate,
            address authorizedCaller
        )
    {
        _getCurPrivateKey();

        uint256 mode = vm.envUint("MODE");
        console.log("mode:", mode == 0 ? "development" : "production");
        if (mode == 0) {
            deployerAddress = vm.addr(deployerPrivateKey);
            owner = deployerAddress;
            withdrawManager = deployerAddress;
            adminFeeRate = 1000; // 10%
            authorizedCaller = deployerAddress;
        } else {
            deployerAddress = vm.addr(deployerPrivateKey);
            owner = vm.envAddress("EVENT_OWNER");
            withdrawManager = vm.envAddress("EVENT_WITHDRAW_MANAGER");
            adminFeeRate = vm.envUint("EVENT_ADMIN_FEE_RATE");
            try vm.envAddress("EVENT_AUTHORIZED_CALLER") returns (address caller) {
                authorizedCaller = caller;
            } catch {
                authorizedCaller = address(0);
            }
        }
    }
}
