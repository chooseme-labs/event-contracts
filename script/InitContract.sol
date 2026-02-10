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
import {CapitalManager} from "../src/token/allocation/CapitalManager.sol";
import {EcosystemManager} from "../src/token/allocation/EcosystemManager.sol";
import {TechManager} from "../src/token/allocation/TechManager.sol";
import {NodeManager} from "../src/staking/NodeManager.sol";
import {StakingManager} from "../src/staking/StakingManager.sol";
import {EventFundingManager} from "../src/staking/EventFundingManager.sol";
import {SubTokenFundingManager} from "../src/staking/SubTokenFundingManager.sol";

import "./EnvContract.sol";

contract TestUSDT is ERC20 {
    constructor() ERC20("TestUSDT", "USDT") {
        _mint(msg.sender, 10000000 * 10 ** 18);
    }
}

contract InitContract is EnvContract {
    EmptyContract public emptyContract;
    ProxyAdmin public chooseMeTokenProxyAdmin;
    ProxyAdmin public nodeManagerProxyAdmin;
    ProxyAdmin public stakingManagerProxyAdmin;
    ProxyAdmin public daoRewardManagerProxyAdmin;
    ProxyAdmin public fomoTreasureManagerProxyAdmin;
    ProxyAdmin public eventFundingManagerProxyAdmin;
    ProxyAdmin public subTokenFundingManagerProxyAdmin;
    ProxyAdmin public marketManagerProxyAdmin;
    ProxyAdmin public airdropManagerProxyAdmin;
    ProxyAdmin public ecosystemManagerProxyAdmin;
    ProxyAdmin public capitalManagerProxyAdmin;
    ProxyAdmin public techManagerProxyAdmin;

    ERC20 public usdt;
    ChooseMeToken public chooseMeToken;
    NodeManager public nodeManager;
    StakingManager public stakingManager;
    DaoRewardManager public daoRewardManager;
    FomoTreasureManager public fomoTreasureManager;
    EventFundingManager public eventFundingManager;
    SubTokenFundingManager public subTokenFundingManager;
    MarketManager public marketManager;
    MarketManager[10] public marketManagers;
    AirdropManager public airdropManager;
    EcosystemManager public ecosystemManager;
    CapitalManager public capitalManager;
    TechManager public techManager;

    IPancakeV2Router public pancakeRouter;
    IPancakeV2Factory public pancakeFactory;
    IPancakeV2Pair public pancakePair;

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
            address[10] memory proxyMarketManagers,
            address proxySubTokenFundingManager,
            address proxyEcosystemManager,
            address proxyCapitalManager,
            address proxyTechManager
        ) = getAddresses();

        usdt = TestUSDT(payable(usdtTokenAddress));
        chooseMeToken = ChooseMeToken(payable(proxyChooseMeToken));
        daoRewardManager = DaoRewardManager(payable(proxyDaoRewardManager));
        eventFundingManager = EventFundingManager(payable(proxyEventFundingManager));
        fomoTreasureManager = FomoTreasureManager(payable(proxyFomoTreasureManager));
        nodeManager = NodeManager(payable(proxyNodeManager));
        stakingManager = StakingManager(payable(proxyStakingManager));
        subTokenFundingManager = SubTokenFundingManager(payable(proxySubTokenFundingManager));
        for (uint256 i = 0; i < 10; i++) {
            marketManagers[i] = MarketManager(payable(proxyMarketManagers[i]));
        }
        marketManager = marketManagers[0];
        airdropManager = AirdropManager(payable(proxyAirdropManager));
        ecosystemManager = EcosystemManager(payable(proxyEcosystemManager));
        capitalManager = CapitalManager(payable(proxyCapitalManager));
        techManager = TechManager(payable(proxyTechManager));

        pancakeRouter = IPancakeV2Router(0x10ED43C718714eb63d5aA57B78B54704E256024E); // PancakeSwap Router V2
        pancakeFactory = IPancakeV2Factory(pancakeRouter.factory());
        pancakePair = IPancakeV2Pair(pancakeFactory.getPair(address(usdt), address(chooseMeToken)));

        chooseMeTokenProxyAdmin = ProxyAdmin(getProxyAdminAddress(proxyChooseMeToken));
        nodeManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(proxyNodeManager));
        stakingManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(proxyStakingManager));
        daoRewardManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(proxyDaoRewardManager));
        fomoTreasureManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(proxyFomoTreasureManager));
        eventFundingManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(proxyEventFundingManager));
        subTokenFundingManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(proxySubTokenFundingManager));
        airdropManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(proxyAirdropManager));
        ecosystemManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(proxyEcosystemManager));
        capitalManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(proxyCapitalManager));
        techManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(proxyTechManager));
        marketManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(proxyMarketManagers[0]));
    }
}
