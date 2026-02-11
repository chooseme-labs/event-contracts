// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract EnvContract is Script {
    function getAddresses()
        internal
        returns (
            address usdtTokenAddress,
            address proxyChooseMeToken,
            address proxyStakingManager,
            address proxyNodeManager,
            address proxyDaoRewardManager,
            address proxyFomoTreasureManager,
            address proxyEventFundingManager,
            address proxyAirdropManager,
            address[10] memory proxyMarketManagers,
            address proxySubTokenFundingManager,
            address proxyEcosystemManager,
            address proxyCapitalManager,
            address proxyTechManager
        )
    {
        string memory json = vm.readFile(getDeployPath());
        try vm.parseJsonAddress(json, ".usdtTokenAddress") returns (address _usdtTokenAddress) {
            usdtTokenAddress = _usdtTokenAddress;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyChooseMeToken") returns (address _proxyChooseMeToken) {
            proxyChooseMeToken = _proxyChooseMeToken;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyStakingManager") returns (address _proxyStakingManager) {
            proxyStakingManager = _proxyStakingManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyNodeManager") returns (address _proxyNodeManager) {
            proxyNodeManager = _proxyNodeManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyDaoRewardManager") returns (address _proxyDaoRewardManager) {
            proxyDaoRewardManager = _proxyDaoRewardManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyFomoTreasureManager") returns (address _proxyFomoTreasureManager) {
            proxyFomoTreasureManager = _proxyFomoTreasureManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyEventFundingManager") returns (address _proxyEventFundingManager) {
            proxyEventFundingManager = _proxyEventFundingManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyAirdropManager") returns (address _proxyAirdropManager) {
            proxyAirdropManager = _proxyAirdropManager;
        } catch {}
        for (uint256 i = 0; i < 10; i++) {
            try vm.parseJsonAddress(json, string(abi.encodePacked(".proxyMarketManager", vm.toString(i)))) returns (
                address _proxyMarketManager
            ) {
                proxyMarketManagers[i] = _proxyMarketManager;
            } catch {}
        }
        try vm.parseJsonAddress(json, ".proxyEcosystemManager") returns (address _proxyEcosystemManager) {
            proxyEcosystemManager = _proxyEcosystemManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxySubTokenFundingManager") returns (address _proxySubTokenFundingManager) {
            proxySubTokenFundingManager = _proxySubTokenFundingManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyCapitalManager") returns (address _proxyCapitalManager) {
            proxyCapitalManager = _proxyCapitalManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyTechManager") returns (address _proxyTechManager) {
            proxyTechManager = _proxyTechManager;
        } catch {}
    }

    function getEventAddresses()
        internal
        returns (
            address proxyAdminFeeVault,
            address proxyFeeVaultManager,
            address proxyFundingManager,
            address proxyFeeVaultPod,
            address proxyFundingPod,
            address mockERC20
        )
    {
        string memory json = vm.readFile(getEventDeployPath());
        try vm.parseJsonAddress(json, ".proxyAdminFeeVault") returns (address _proxyAdminFeeVault) {
            proxyAdminFeeVault = _proxyAdminFeeVault;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyFeeVaultManager") returns (address _proxyFeeVaultManager) {
            proxyFeeVaultManager = _proxyFeeVaultManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyFundingManager") returns (address _proxyFundingManager) {
            proxyFundingManager = _proxyFundingManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyFeeVaultPod") returns (address _proxyFeeVaultPod) {
            proxyFeeVaultPod = _proxyFeeVaultPod;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyFundingPod") returns (address _proxyFundingPod) {
            proxyFundingPod = _proxyFundingPod;
        } catch {}
        try vm.parseJsonAddress(json, ".mockERC20") returns (address _mockERC20) {
            mockERC20 = _mockERC20;
        } catch {}
    }

    function getDeployPath() public view returns (string memory) {
        uint256 mode = vm.envUint("MODE");
        if (mode == 0) {
            return string(abi.encodePacked("./cache/__deployed_addresses_dev", ".json"));
        } else {
            return string(abi.encodePacked("./cache/__deployed_addresses_prod", ".json"));
        }
    }

    function getEventDeployPath() public view returns (string memory) {
        uint256 mode = vm.envUint("MODE");
        if (mode == 0) {
            return string(abi.encodePacked("./cache/__deployed_addresses_event_dev", ".json"));
        } else {
            return string(abi.encodePacked("./cache/__deployed_addresses_event_prod", ".json"));
        }
    }

    function getCurPrivateKey() public view returns (uint256 deployerPrivateKey) {
        uint256 mode = vm.envUint("MODE");
        if (mode == 0) {
            deployerPrivateKey = vm.envUint("DEV_PRIVATE_KEY");
        } else {
            deployerPrivateKey = vm.envUint("PROD_PRIVATE_KEY");
        }
    }

    function getProxyAdminAddress(address proxy) internal view returns (address) {
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm vm = Vm(CHEATCODE_ADDRESS);

        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }
}
