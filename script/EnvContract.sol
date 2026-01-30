// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";

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
            address proxyMarketManager,
            address proxySubTokenFundingManager
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
        try vm.parseJsonAddress(json, ".proxyMarketManager") returns (address _proxyMarketManager) {
            proxyMarketManager = _proxyMarketManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxySubTokenFundingManager") returns (address _proxySubTokenFundingManager) {
            proxySubTokenFundingManager = _proxySubTokenFundingManager;
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

    function getCurPrivateKey() public view returns (uint256 deployerPrivateKey) {
        uint256 mode = vm.envUint("MODE");
        if (mode == 0) {
            deployerPrivateKey = vm.envUint("DEV_PRIVATE_KEY");
        } else {
            deployerPrivateKey = vm.envUint("PROD_PRIVATE_KEY");
        }
    }
}
