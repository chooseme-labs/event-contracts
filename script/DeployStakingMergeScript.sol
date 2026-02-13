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
import {NodeManager} from "../src/staking/NodeManager.sol";
import {StakingManager} from "../src/staking/StakingManager.sol";
import {EventFundingManager} from "../src/staking/EventFundingManager.sol";
import {SubTokenFundingManager} from "../src/staking/SubTokenFundingManager.sol";

import "./InitContract.sol";

contract DeployStakingMergeScript is Script, InitContract {
    uint256 deployerPrivateKey;

    // MODE=1 forge script DeployStakingMergeScript --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --slow --multi --sig "run()"
    function run() public {
        initContracts();
        deployerPrivateKey = getCurPrivateKey();

        address[] memory buyers = new address[](1);
        buyers[0] = 0xA84b0a4f30679d16a3056569C16A323689D5e7F7;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 500 ether;

        vm.startBroadcast(deployerPrivateKey);
        nodeManager.purchaseNodeBatch(buyers, amounts);
        vm.stopBroadcast();
    }

    // MODE=1 forge script DeployStakingMergeScript --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --slow --multi --sig "mergeInviters(uint256)" 0
    // MODE=1 forge script DeployStakingMergeScript --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --slow --multi --broadcast --sig "mergeInviters(uint256)" 0
    function mergeInviters(uint256 start) public {
        initContracts();
        deployerPrivateKey = getCurPrivateKey();
        uint256 max = 100;
        uint256 step = 20;

        NodeManager nodeManagerOld = NodeManager(0x9527e8Fce047226Cf666289d9C93E5C334Ca0B79);

        string memory json = vm.readFile("cache/__users.json");
        address[] memory _users = new address[](step);
        address[] memory _inviters = new address[](step);
        uint256 curI = 0;

        for (uint256 i = 0; i < step; i++) {
            address user;
            try vm.parseJsonAddress(json, string(abi.encodePacked("[", Strings.toString(start + i), "]"))) returns (
                address _user
            ) {
                user = _user;
            } catch {}

            address inviter = nodeManagerOld.inviters(user);
            address inviter2 = nodeManager.inviters(user);
            // console.log("user:", user, "inviter:", inviter);
            if (inviter != address(0) && inviter2 == address(0)) {
                _users[curI] = user;
                _inviters[curI] = inviter;
                curI++;
            }
        }

        address[] memory users = new address[](curI);
        address[] memory inviters = new address[](curI);

        for (uint256 i = 0; i < curI; i++) {
            users[i] = _users[i];
            inviters[i] = _inviters[i];
            console.log("==========", i, _users[i], _inviters[i]);
        }

        console.log("123123", users.length, inviters.length, start + step);

        vm.startBroadcast(deployerPrivateKey);
        nodeManager.bindInviterBatch(inviters, users);
        vm.stopBroadcast();
    }

    // MODE=1 forge script DeployStakingMergeScript --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --slow --multi --sig "inviterValid(uint256)" 0
    function inviterValid(uint256 start) public {
        initContracts();
        uint256 step = 50;

        NodeManager nodeManagerOld = NodeManager(0x9527e8Fce047226Cf666289d9C93E5C334Ca0B79);

        string memory json = vm.readFile("cache/__users.json");
        for (uint256 i = 0; i < step; i++) {
            address user = vm.parseJsonAddress(json, string(abi.encodePacked("[", Strings.toString(start + i), "]")));
            address inviter = nodeManagerOld.inviters(user);
            address inviter2 = nodeManager.inviters(user);
            if (inviter != inviter2) {
                console.log("invalid inviter:", user, inviter, inviter2);
            }
        }
    }

    // MODE=1 forge script DeployStakingMergeScript --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --slow --multi --sig "mergeNodes(uint256)" 0
    // MODE=1 forge script DeployStakingMergeScript --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast --slow --multi --sig "mergeNodes(uint256)" 0
    function mergeNodes(uint256 start) public {
        initContracts();
        deployerPrivateKey = getCurPrivateKey();
        uint256 max = 100;
        uint256 step = 20;

        NodeManager nodeManagerOld = NodeManager(0x9527e8Fce047226Cf666289d9C93E5C334Ca0B79);

        string memory json = vm.readFile("cache/__users.json");

        uint256 i = 0;
        address[] memory _users = new address[](step);
        uint256[] memory _amounts = new uint256[](step);
        uint256 curI = 0;

        while (i < step) {
            address user;
            try vm.parseJsonAddress(json, string(abi.encodePacked("[", Strings.toString(start + i), "]"))) returns (
                address _user
            ) {
                user = _user;
            } catch {}

            (address buyer, uint8 nodeType, uint256 amount) = nodeManagerOld.nodeBuyerInfo(user);

            (address buyer2, uint8 nodeType2, uint256 amount2) = nodeManager.nodeBuyerInfo(user);
            if (buyer != address(0) && buyer2 == address(0)) {
                _users[curI] = user;
                _amounts[curI] = amount;
                curI++;
            } else {
                console.log("no node:", user);
            }
            i++;
        }

        address[] memory users = new address[](curI);
        uint256[] memory amounts = new uint256[](curI);

        for (uint256 i = 0; i < curI; i++) {
            users[i] = _users[i];
            amounts[i] = _amounts[i];
        }
        console.log("123123", users.length, amounts.length, start + step);

        vm.startBroadcast(deployerPrivateKey);
        nodeManager.purchaseNodeBatch(users, amounts);
        vm.stopBroadcast();
    }

    // MODE=1 forge script DeployStakingMergeScript --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --slow --multi --sig "nodeValid(uint256)" 0
    function nodeValid(uint256 start) public {
        initContracts();
        uint256 step = 30;

        NodeManager nodeManagerOld = NodeManager(0x9527e8Fce047226Cf666289d9C93E5C334Ca0B79);

        string memory json = vm.readFile("cache/__users.json");
        for (uint256 i = 0; i < step; i++) {
            address user;
            try vm.parseJsonAddress(json, string(abi.encodePacked("[", Strings.toString(start + i), "]"))) returns (
                address _user
            ) {
                user = _user;
            } catch {}

            (address buyer, uint8 nodeType, uint256 amount) = nodeManagerOld.nodeBuyerInfo(user);
            (address buyer1, uint8 nodeType1, uint256 amount1) = nodeManager.nodeBuyerInfo(user);
            if (amount != amount1) {
                console.log("invalid node:", user, amount, amount1);
            }
        }
    }

    // MODE=1 forge script DeployStakingMergeScript --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast --slow --multi --sig "transferRelativeship()"
    function transferRelativeship() public {
        initContracts();
        uint256 deployerPrivateKey = getCurPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        address OWNER = vm.envAddress("OWNER");
        address MANAGER = vm.envAddress("MANAGER");
        address OPERATOR = vm.envAddress("OPERATOR");
        address CALLER = vm.envAddress("CALLER");

        // chooseMeToken.setOperator(OPERATOR);
        // chooseMeToken.transferOwnership(OWNER);

        // nodeManager.setManager(MANAGER);
        // nodeManager.transferOwnership(OWNER);
        // stakingManagerProxyAdmin.transferOwnership(OWNER);
        // chooseMeTokenProxyAdmin.transferOwnership(OWNER);

        // nodeManager.setDistributeRewardAddress(CALLER);

        // stakingManager.setManager(MANAGER);
        // stakingManager.transferOwnership(OWNER);
        // stakingManager.setStakingOperatorManager(CALLER);

        // daoRewardManager.setManager(MANAGER);
        // daoRewardManager.transferOwnership(OWNER);

        // fomoTreasureManager.setManager(MANAGER);
        // fomoTreasureManager.transferOwnership(OWNER);

        // eventFundingManager.setManager(MANAGER);
        // eventFundingManager.transferOwnership(OWNER);

        // subTokenFundingManager.setOperator(OPERATOR);
        // subTokenFundingManager.setManager(MANAGER);
        // subTokenFundingManager.transferOwnership(OWNER);

        // airdropManager.setManager(MANAGER);
        // airdropManager.transferOwnership(OWNER);

        // ecosystemManager.setManager(MANAGER);
        // ecosystemManager.transferOwnership(OWNER);

        // capitalManager.setManager(MANAGER);
        // capitalManager.transferOwnership(OWNER);

        // techManager.setManager(MANAGER);
        // techManager.transferOwnership(OWNER);

        // for (uint256 i = 0; i < 10; i++) {
        //     marketManagers[i].setManager(MANAGER);
        //     marketManagers[i].transferOwnership(OWNER);
        // }
    }
}
