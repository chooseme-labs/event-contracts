// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {EmptyContract} from "../src/utils/EmptyContract.sol";
import {IChooseMeToken} from "../src/interfaces/token/IChooseMeToken.sol";
import {ChooseMeToken} from "../src/token/ChooseMeToken.sol";
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
        _mint(msg.sender, 100000000 * 10 ** 18);
    }
}

// MODE=1 forge script DeployStakingScript --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast --verify --etherscan-api-key I4C1AKJT8J9KJVCXHZKK317T3XV8IVASRX
// forge verify-contract --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --etherscan-api-key I4C1AKJT8J9KJVCXHZKK317T3XV8IVASRX 0x97807b490Bb554a910f542693105d65742DaaAc9

contract DeployStakingScript is Script, EnvContract {
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

    ChooseMeToken public chooseMeTokenImplementation;
    ChooseMeToken public chooseMeToken;

    NodeManager public nodeManagerImplementation;
    NodeManager public nodeManager;

    StakingManager public stakingManagerImplementation;
    StakingManager public stakingManager;

    DaoRewardManager public daoRewardManagerImplementation;
    DaoRewardManager public daoRewardManager;

    FomoTreasureManager public fomoTreasureManagerImplementation;
    FomoTreasureManager public fomoTreasureManager;

    EventFundingManager public eventFundingManagerImplementation;
    EventFundingManager public eventFundingManager;

    SubTokenFundingManager public subTokenFundingManagerImplementation;
    SubTokenFundingManager public subTokenFundingManager;

    MarketManager public marketManagerImplementation;
    MarketManager[10] public marketManagers;

    AirdropManager public airdropManagerImplementation;
    AirdropManager public airdropManager;

    EcosystemManager public ecosystemManagerImplementation;
    EcosystemManager public ecosystemManager;

    CapitalManager public capitalManagerImplementation;
    CapitalManager public capitalManager;

    TechManager public techManagerImplementation;
    TechManager public techManager;

    TestUSDT public usdt;

    uint256 deployerPrivateKey;

    // MODE=1 forge script DeployStakingScript --sig "deploy1()"  --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast
    function deploy1() public {
        (
            address deployerAddress,
            address distributeRewardAddress,
            address chooseMeMultiSign,
            address chooseMeMultiSign2,
            address usdtTokenAddress
        ) = getENVAddress();

        vm.startBroadcast(deployerPrivateKey);

        emptyContract = new EmptyContract();

        TransparentUpgradeableProxy proxyNodeManager =
            new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
        nodeManager = NodeManager(payable(address(proxyNodeManager)));
        nodeManagerImplementation = new NodeManager();
        nodeManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyNodeManager)));

        nodeManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(nodeManager)),
            address(nodeManagerImplementation),
            abi.encodeWithSelector(
                NodeManager.initialize.selector,
                chooseMeMultiSign,
                chooseMeMultiSign2,
                usdtTokenAddress,
                distributeRewardAddress
            )
        );

        (address user1, address user2, address user3, address user4) = getTopUser();

        nodeManager.bindRootInviter(user1, user2);
        nodeManager.bindRootInviter(user2, user3);
        nodeManager.bindRootInviter(user3, user4);

        vm.stopBroadcast();

        console.log("deploy usdtTokenAddress:", address(usdtTokenAddress));
        console.log("deploy nodeManager:", address(nodeManager));
        console.log("user4:", user4);

        string memory obj = "{}";
        vm.serializeAddress(obj, "usdtTokenAddress", usdtTokenAddress);
        string memory finalJSON = vm.serializeAddress(obj, "proxyNodeManager", address(proxyNodeManager));
        vm.writeJson(finalJSON, getDeployPath());
    }

    // MODE=1 forge script DeployStakingScript --sig "deploy2()"  --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast --verify --etherscan-api-key I4C1AKJT8J9KJVCXHZKK317T3XV8IVASRX
    function deploy2() public {
        (
            address deployerAddress,
            address distributeRewardAddress,
            address chooseMeMultiSign,
            address chooseMeMultiSign2,
            address usdtTokenAddress
        ) = getENVAddress();

        vm.startBroadcast(deployerPrivateKey);

        emptyContract = new EmptyContract();

        TransparentUpgradeableProxy proxyChooseMeToken =
            new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
        chooseMeToken = ChooseMeToken(address(proxyChooseMeToken));
        chooseMeTokenImplementation = new ChooseMeToken();
        chooseMeTokenProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyChooseMeToken)));

        TransparentUpgradeableProxy proxyNodeManager =
            new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
        nodeManager = NodeManager(payable(address(proxyNodeManager)));
        nodeManagerImplementation = new NodeManager();
        nodeManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyNodeManager)));

        TransparentUpgradeableProxy proxyStakingManager =
            new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
        stakingManager = StakingManager(payable(address(proxyStakingManager)));
        stakingManagerImplementation = new StakingManager();
        stakingManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyStakingManager)));

        TransparentUpgradeableProxy proxyDaoRewardManager =
            new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
        daoRewardManager = DaoRewardManager(payable(address(proxyDaoRewardManager)));
        daoRewardManagerImplementation = new DaoRewardManager();
        daoRewardManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyDaoRewardManager)));

        TransparentUpgradeableProxy proxyEventFundingManager =
            new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
        eventFundingManager = EventFundingManager(payable(address(proxyEventFundingManager)));
        eventFundingManagerImplementation = new EventFundingManager();
        eventFundingManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyEventFundingManager)));

        TransparentUpgradeableProxy proxyFomoTreasureManager =
            new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
        fomoTreasureManager = FomoTreasureManager(payable(address(proxyFomoTreasureManager)));
        fomoTreasureManagerImplementation = new FomoTreasureManager();
        fomoTreasureManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyFomoTreasureManager)));

        TransparentUpgradeableProxy proxySubTokenFundingManager =
            new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
        subTokenFundingManager = SubTokenFundingManager(payable(address(proxySubTokenFundingManager)));
        subTokenFundingManagerImplementation = new SubTokenFundingManager();
        subTokenFundingManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxySubTokenFundingManager)));

        // Deploy 10 MarketManager contracts
        marketManagerImplementation = new MarketManager();
        for (uint256 i = 0; i < 10; i++) {
            TransparentUpgradeableProxy proxyMarketManager =
                new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
            marketManagers[i] = MarketManager(payable(address(proxyMarketManager)));
            ProxyAdmin tempProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyMarketManager)));
            tempProxyAdmin.upgradeAndCall(
                ITransparentUpgradeableProxy(address(marketManagers[i])),
                address(marketManagerImplementation),
                abi.encodeWithSelector(
                    MarketManager.initialize.selector, chooseMeMultiSign, chooseMeMultiSign, address(chooseMeToken)
                )
            );
        }

        TransparentUpgradeableProxy proxyAirdropManager =
            new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
        airdropManager = AirdropManager(payable(address(proxyAirdropManager)));
        airdropManagerImplementation = new AirdropManager();
        airdropManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyAirdropManager)));

        TransparentUpgradeableProxy proxyEcosystemManager =
            new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
        ecosystemManager = EcosystemManager(payable(address(proxyEcosystemManager)));
        ecosystemManagerImplementation = new EcosystemManager();
        ecosystemManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyEcosystemManager)));

        TransparentUpgradeableProxy proxyCapitalManager =
            new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
        capitalManager = CapitalManager(payable(address(proxyCapitalManager)));
        capitalManagerImplementation = new CapitalManager();
        capitalManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyCapitalManager)));

        TransparentUpgradeableProxy proxyTechManager =
            new TransparentUpgradeableProxy(address(emptyContract), chooseMeMultiSign, "");
        techManager = TechManager(payable(address(proxyTechManager)));
        techManagerImplementation = new TechManager();
        techManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyTechManager)));

        chooseMeTokenProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(chooseMeToken)),
            address(chooseMeTokenImplementation),
            abi.encodeWithSelector(
                ChooseMeToken.initialize.selector, chooseMeMultiSign, address(stakingManager), usdtTokenAddress
            )
        );

        nodeManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(nodeManager)),
            address(nodeManagerImplementation),
            abi.encodeWithSelector(
                NodeManager.initialize.selector,
                chooseMeMultiSign,
                chooseMeMultiSign,
                usdtTokenAddress,
                distributeRewardAddress
            )
        );

        nodeManager.setConfig(address(chooseMeToken), address(proxyDaoRewardManager), address(proxyEventFundingManager));

        (address user1, address user2, address user3, address user4) = getTopUser();
        nodeManager.bindRootInviter(user1, user2);
        nodeManager.bindRootInviter(user2, user3);
        nodeManager.bindRootInviter(user3, user4);

        stakingManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(stakingManager)),
            address(stakingManagerImplementation),
            abi.encodeWithSelector(
                StakingManager.initialize.selector,
                chooseMeMultiSign,
                chooseMeMultiSign,
                address(chooseMeToken),
                usdtTokenAddress,
                distributeRewardAddress,
                address(daoRewardManager),
                address(eventFundingManager),
                address(nodeManager),
                address(subTokenFundingManager)
            )
        );

        daoRewardManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(daoRewardManager)),
            address(daoRewardManagerImplementation),
            abi.encodeWithSelector(DaoRewardManager.initialize.selector, chooseMeMultiSign, address(chooseMeToken))
        );

        daoRewardManager.setAuthorizedCaller(address(nodeManager), true);
        daoRewardManager.setAuthorizedCaller(address(stakingManager), true);

        fomoTreasureManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(fomoTreasureManager)),
            address(fomoTreasureManagerImplementation),
            abi.encodeWithSelector(
                FomoTreasureManager.initialize.selector, chooseMeMultiSign, chooseMeMultiSign, usdtTokenAddress
            )
        );

        eventFundingManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(eventFundingManager)),
            address(eventFundingManagerImplementation),
            abi.encodeWithSelector(
                EventFundingManager.initialize.selector, chooseMeMultiSign, chooseMeMultiSign, usdtTokenAddress
            )
        );

        subTokenFundingManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(subTokenFundingManager)),
            address(subTokenFundingManagerImplementation),
            abi.encodeWithSelector(
                SubTokenFundingManager.initialize.selector,
                chooseMeMultiSign,
                chooseMeMultiSign,
                chooseMeMultiSign,
                usdtTokenAddress
            )
        );

        airdropManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(airdropManager)),
            address(airdropManagerImplementation),
            abi.encodeWithSelector(
                AirdropManager.initialize.selector, chooseMeMultiSign, chooseMeMultiSign, address(chooseMeToken)
            )
        );

        ecosystemManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(ecosystemManager)),
            address(ecosystemManagerImplementation),
            abi.encodeWithSelector(
                EcosystemManager.initialize.selector, chooseMeMultiSign, chooseMeMultiSign, address(chooseMeToken)
            )
        );

        capitalManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(capitalManager)),
            address(capitalManagerImplementation),
            abi.encodeWithSelector(
                CapitalManager.initialize.selector, chooseMeMultiSign, chooseMeMultiSign, address(chooseMeToken)
            )
        );

        techManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(techManager)),
            address(techManagerImplementation),
            abi.encodeWithSelector(
                TechManager.initialize.selector, chooseMeMultiSign, chooseMeMultiSign, address(chooseMeToken)
            )
        );

        vm.stopBroadcast();

        console.log("deploy usdtTokenAddress:", usdtTokenAddress);
        console.log("deploy proxyChooseMeToken:", address(proxyChooseMeToken));
        console.log("deploy proxyStakingManager:", address(proxyStakingManager));
        console.log("deploy proxyNodeManager:", address(proxyNodeManager));
        console.log("deploy proxyDaoRewardManager:", address(proxyDaoRewardManager));
        console.log("deploy proxyFomoTreasureManager:", address(proxyFomoTreasureManager));
        console.log("deploy proxyEventFundingManager:", address(proxyEventFundingManager));
        console.log("deploy proxySubTokenFundingManager:", address(proxySubTokenFundingManager));
        for (uint256 i = 0; i < 10; i++) {
            console.log("deploy proxyMarketManager", i, ":", address(marketManagers[i]));
        }
        console.log("deploy proxyAirdropManager:", address(proxyAirdropManager));
        console.log("deploy proxyEcosystemManager:", address(proxyEcosystemManager));
        console.log("deploy proxyCapitalManager:", address(proxyCapitalManager));
        console.log("deploy proxyTechManager:", address(proxyTechManager));

        string memory obj = "{}";
        vm.serializeAddress(obj, "usdtTokenAddress", usdtTokenAddress);
        vm.serializeAddress(obj, "proxyChooseMeToken", address(proxyChooseMeToken));
        vm.serializeAddress(obj, "proxyStakingManager", address(proxyStakingManager));
        vm.serializeAddress(obj, "proxyNodeManager", address(proxyNodeManager));
        vm.serializeAddress(obj, "proxyDaoRewardManager", address(proxyDaoRewardManager));
        vm.serializeAddress(obj, "proxyFomoTreasureManager", address(proxyFomoTreasureManager));
        vm.serializeAddress(obj, "proxyEventFundingManager", address(proxyEventFundingManager));
        for (uint256 i = 0; i < 10; i++) {
            vm.serializeAddress(
                obj, string(abi.encodePacked("proxyMarketManager", Strings.toString(i))), address(marketManagers[i])
            );
        }
        vm.serializeAddress(obj, "proxyAirdropManager", address(proxyAirdropManager));
        vm.serializeAddress(obj, "proxyEcosystemManager", address(proxyEcosystemManager));
        vm.serializeAddress(obj, "proxyCapitalManager", address(proxyCapitalManager));
        vm.serializeAddress(obj, "proxyTechManager", address(proxyTechManager));

        string memory finalJSON =
            vm.serializeAddress(obj, "proxySubTokenFundingManager", address(proxySubTokenFundingManager));
        vm.writeJson(finalJSON, getDeployPath());
    }

    // MODE=1 forge script DeployStakingScript --sig "update()"  --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast --verify --etherscan-api-key I4C1AKJT8J9KJVCXHZKK317T3XV8IVASRX
    function update() public {
        initContracts();
        _getCurPrivateKey();

        vm.startBroadcast(deployerPrivateKey);

        // nodeManagerImplementation = new NodeManager();
        // nodeManagerProxyAdmin.upgradeAndCall(
        //     ITransparentUpgradeableProxy(address(nodeManager)), address(nodeManagerImplementation), ""
        // );

        // stakingManagerImplementation = new StakingManager();
        // stakingManagerProxyAdmin.upgradeAndCall(
        //     ITransparentUpgradeableProxy(address(stakingManager)), address(stakingManagerImplementation), ""
        // );

        chooseMeTokenImplementation = new ChooseMeToken();
        console.log("chooseMeTokenImplementation:", address(chooseMeTokenImplementation));
        chooseMeTokenProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(chooseMeToken)), address(chooseMeTokenImplementation), ""
        );

        vm.stopBroadcast();
    }

    // MODE=1 forge script DeployStakingScript --sig "initChooseMeToken()"  --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast
    function initChooseMeToken() public {
        initContracts();

        if (chooseMeToken.balanceOf(address(daoRewardManager)) > 0) return;

        IChooseMeToken.ChooseMePool memory pools = IChooseMeToken.ChooseMePool({
            nodePool: address(nodeManager),
            techPool: address(techManager),
            techFeePool: 0x6a5B9eA64FB76adbA3990E7F2F5dEc82495f00ba,
            capitalPool: address(capitalManager),
            daoRewardPool: address(daoRewardManager),
            airdropPool: address(airdropManager),
            marketingFeePool: 0xbC581DF4915b012B04DD0751540F8f328b2fDf0E,
            ecosystemPool: address(ecosystemManager),
            subTokenPool: address(subTokenFundingManager)
        });

        address[] memory marketingPools = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            marketingPools[i] = address(marketManagers[i]);
        }

        _getCurPrivateKey();
        vm.startBroadcast(deployerPrivateKey);
        chooseMeToken.setPoolAddress(pools, marketingPools);
        console.log("Pool addresses set");

        // Execute pool allocation
        chooseMeToken.poolAllocate();
        console.log("Pool allocation completed");
        console.log("Total Supply:", chooseMeToken.totalSupply() / 1e6, "CMT");

        vm.stopBroadcast();
    }

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
        airdropManager = AirdropManager(payable(proxyAirdropManager));
        ecosystemManager = EcosystemManager(payable(proxyEcosystemManager));
        capitalManager = CapitalManager(payable(proxyCapitalManager));
        techManager = TechManager(payable(proxyTechManager));

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

        console.log("Contracts initialized");
    }

    function getProxyAdminAddress(address proxy) internal view returns (address) {
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm vm = Vm(CHEATCODE_ADDRESS);

        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }

    function _getCurPrivateKey() public returns (uint256) {
        deployerPrivateKey = super.getCurPrivateKey();
    }

    function getENVAddress()
        public
        returns (
            address deployerAddress,
            address distributeRewardAddress,
            address chooseMeMultiSign,
            address chooseMeMultiSign2,
            address usdtTokenAddress
        )
    {
        _getCurPrivateKey();

        uint256 mode = vm.envUint("MODE");
        console.log("mode:", mode == 0 ? "development" : "production");
        if (mode == 0) {
            vm.startBroadcast(deployerPrivateKey);
            deployerAddress = vm.addr(deployerPrivateKey);
            distributeRewardAddress = deployerAddress;
            chooseMeMultiSign = deployerAddress;
            chooseMeMultiSign2 = deployerAddress;
            ERC20 usdtToken = new TestUSDT();
            usdtTokenAddress = address(usdtToken);
            vm.stopBroadcast();
        } else {
            deployerAddress = vm.addr(deployerPrivateKey);
            distributeRewardAddress = vm.envAddress("DR_ADDRESS"); //TODO
            chooseMeMultiSign = vm.envAddress("MULTI_SIGNER");
            chooseMeMultiSign2 = vm.envAddress("MULTI_SIGNER_2");
            usdtTokenAddress = vm.envAddress("USDT_TOKEN_ADDRESS");
        }
    }

    function getTopUser() public view returns (address user1, address user2, address user3, address user4) {
        uint256 mode = vm.envUint("MODE");
        if (mode == 0) {
            user1 = vm.envAddress("DEV_TOP_USER_1");
            user2 = vm.envAddress("DEV_TOP_USER_2");
            user3 = vm.envAddress("DEV_TOP_USER_3");
            user4 = vm.envAddress("DEV_TOP_USER_4");
        } else {
            user1 = vm.envAddress("PROD_TOP_USER_1");
            user2 = vm.envAddress("PROD_TOP_USER_2");
            user3 = vm.envAddress("PROD_TOP_USER_3");
            user4 = vm.envAddress("PROD_TOP_USER_4");
        }
    }
}
