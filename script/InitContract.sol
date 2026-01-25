// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IPancakeV2Factory} from "../src/interfaces/staking/pancake/IPancakeV2Factory.sol";
import {IPancakeV2Router} from "../src/interfaces/staking/pancake/IPancakeV2Router.sol";
import {IPancakeV2Pair} from "../src/interfaces/staking/pancake/IPancakeV2Pair.sol";

import {EmptyContract} from "../src/utils/EmptyContract.sol";
import {ChooseMeToken} from "../src/token/ChooseMeToken.sol";
import {IChooseMeToken} from "../src/interfaces/token/IChooseMeToken.sol";
import {DaoRewardManager} from "../src/token/allocation/DaoRewardManager.sol";
import {FomoTreasureManager} from "../src/token/allocation/FomoTreasureManager.sol";
import {AirdropManager} from "../src/token/allocation/AirdropManager.sol";
import {MarketManager} from "../src/token/allocation/MarketManager.sol";
import {NodeManager} from "../src/staking/NodeManager.sol";
import {StakingManager} from "../src/staking/StakingManager.sol";
import {EventFundingManager} from "../src/staking/EventFundingManager.sol";
import {SubTokenFundingManager} from "../src/staking/SubTokenFundingManager.sol";

contract TestUSDT is ERC20 {
    constructor() ERC20("TestUSDT", "USDT") {
        _mint(msg.sender, 10000000 * 10 ** 18);
    }
}

contract InitContract is Script {
    ERC20 public usdt;
    ChooseMeToken public chooseMeToken;
    NodeManager public nodeManager;
    StakingManager public stakingManager;
    DaoRewardManager public daoRewardManager;
    FomoTreasureManager public fomoTreasureManager;
    EventFundingManager public eventFundingManager;
    SubTokenFundingManager public subTokenFundingManager;
    MarketManager public marketManager;
    AirdropManager public airdropManager;

    IPancakeV2Router public pancakeRouter;

    function initContracts() internal {
        (
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
        ) = getAddresses();

        usdt = TestUSDT(payable(usdtTokenAddress));
        chooseMeToken = ChooseMeToken(payable(proxyChooseMeToken));
        daoRewardManager = DaoRewardManager(payable(proxyDaoRewardManager));
        eventFundingManager = EventFundingManager(payable(proxyEventFundingManager));
        fomoTreasureManager = FomoTreasureManager(payable(proxyFomoTreasureManager));
        nodeManager = NodeManager(payable(proxyNodeManager));
        stakingManager = StakingManager(payable(proxyStakingManager));
        subTokenFundingManager = SubTokenFundingManager(payable(proxySubTokenFundingManager));
        marketManager = MarketManager(payable(proxyMarketManager));
        airdropManager = AirdropManager(payable(proxyAirdropManager));

        pancakeRouter = IPancakeV2Router(0x10ED43C718714eb63d5aA57B78B54704E256024E); // PancakeSwap Router V2
    }

    function getAddresses()
        internal
        returns (
            address usdtAddress,
            address chooseMeTokenAddress,
            address stakingManagerAddress,
            address nodeManagerAddress,
            address daoRewardManagerAddress,
            address fomoTreasureManagerAddress,
            address eventFundingManagerAddress,
            address airdropManagerAddress,
            address marketManagerAddress,
            address subTokenFundingManagerAddress
        )
    {
        string memory json = vm.readFile(getDeployPath());
        try vm.parseJsonAddress(json, ".usdtTokenAddress") returns (address _usdtTokenAddress) {
            usdtAddress = _usdtTokenAddress;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyChooseMeToken") returns (address _proxyChooseMeToken) {
            chooseMeTokenAddress = _proxyChooseMeToken;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyStakingManager") returns (address _proxyStakingManager) {
            stakingManagerAddress = _proxyStakingManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyNodeManager") returns (address _proxyNodeManager) {
            nodeManagerAddress = _proxyNodeManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyDaoRewardManager") returns (address _proxyDaoRewardManager) {
            daoRewardManagerAddress = _proxyDaoRewardManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyFomoTreasureManager") returns (address _proxyFomoTreasureManager) {
            fomoTreasureManagerAddress = _proxyFomoTreasureManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyEventFundingManager") returns (address _proxyEventFundingManager) {
            eventFundingManagerAddress = _proxyEventFundingManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyAirdropManager") returns (address _proxyAirdropManager) {
            airdropManagerAddress = _proxyAirdropManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxyMarketManager") returns (address _proxyMarketManager) {
            marketManagerAddress = _proxyMarketManager;
        } catch {}
        try vm.parseJsonAddress(json, ".proxySubTokenFundingManager") returns (address _proxySubTokenFundingManager) {
            subTokenFundingManagerAddress = _proxySubTokenFundingManager;
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
}
