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
contract DeployStakingScript2 is Script, EnvContract {
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

    // MODE=1 forge script DeployStakingScript2 --sig "update()"  --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast --verify --etherscan-api-key I4C1AKJT8J9KJVCXHZKK317T3XV8IVASRX
    function update() public {
        _getCurPrivateKey();

        vm.startBroadcast(deployerPrivateKey);

        chooseMeTokenImplementation = new ChooseMeToken();
        console.log("chooseMeTokenImplementation:", address(chooseMeTokenImplementation));

        vm.stopBroadcast();
    }

    function _getCurPrivateKey() public returns (uint256) {
        deployerPrivateKey = super.getCurPrivateKey();
    }
}
