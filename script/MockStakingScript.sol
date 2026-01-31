// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./InitContract.sol";

// forge script MockStakingScript --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast
contract MockStakingScript is InitContract {
    function run() public {
        initContracts();

        string memory mnemonic = vm.envString("DEV_MNEMONIC");

        for (uint32 i = 0; i < 5; i++) {
            uint32 mnemonicIndex = i + 10;
            uint256 userKey = vm.deriveKey(mnemonic, mnemonicIndex);
            address user = vm.addr(userKey);

            console.log("PrivateKey:", vm.toString(bytes32(userKey)));
            address inviter = nodeManager.inviters(user);
            console.log("inviter:", user, inviter);
        }
    }

    // forge script MockStakingScript --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast --sig "buyStaking(uint32,uint32)"
    // 40
    // function buyStaking(uint32 start, uint32 end) public {
    //     initContracts();

    //     string memory mnemonic = vm.envString("DEV_MNEMONIC");
    //     uint256 deployerPrivateKey = vm.envUint("DEV_PRIVATE_KEY");
    //     uint32 startIndex = 10;

    //     uint256[] memory stakingAmounts = new uint256[](6);
    //     stakingAmounts[0] = stakingManager.t1Staking();
    //     stakingAmounts[1] = stakingManager.t2Staking();
    //     stakingAmounts[2] = stakingManager.t3Staking();
    //     stakingAmounts[3] = stakingManager.t4Staking();
    //     stakingAmounts[4] = stakingManager.t5Staking();
    //     stakingAmounts[5] = stakingManager.t6Staking();

    //     for (uint32 i = start; i < end; i++) {
    //         uint32 mnemonicIndex = i + startIndex;
    //         uint256 userKey = vm.deriveKey(mnemonic, mnemonicIndex);
    //         address user = vm.addr(userKey);
    //         address inviter = nodeManager.inviters(user);

    //         if (inviter == address(0)) {
    //             continue;
    //         }
    //         uint256 amount = stakingAmounts[i % 3 + 3];
    //         vm.startBroadcast(deployerPrivateKey);
    //         usdt.transfer(user, amount);
    //         payable(user).transfer(0.00004 ether);
    //         vm.stopBroadcast();

    //         vm.startBroadcast(userKey);
    //         usdt.approve(address(stakingManager), amount);
    //         stakingManager.liquidityProviderDeposit(amount);
    //         vm.stopBroadcast();
    //     }
    // }

    // forge script MockStakingScript --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast --sig "buyNode(uint32,uint32)"
    function buyNode(uint32 start, uint32 end) public {
        initContracts();

        string memory mnemonic = vm.envString("DEV_MNEMONIC");
        uint256 deployerPrivateKey = vm.envUint("DEV_PRIVATE_KEY");
        uint32 startIndex = 10;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = nodeManager.buyDistributedNode();
        amounts[1] = nodeManager.buyClusterNode();

        for (uint32 i = start; i < end; i++) {
            uint32 mnemonicIndex = i + startIndex;
            uint256 userKey = vm.deriveKey(mnemonic, mnemonicIndex);
            address user = vm.addr(userKey);
            address inviter = nodeManager.inviters(user);

            (address buyer, uint8 nodeType, uint256 amount) = nodeManager.nodeBuyerInfo(user);
            if (inviter == address(0) && buyer != address(0)) {
                continue;
            }
            uint256 _amount = amounts[i % 2];
            vm.startBroadcast(deployerPrivateKey);
            usdt.transfer(user, _amount);
            payable(user).transfer(0.00004 ether);
            vm.stopBroadcast();

            vm.startBroadcast(userKey);
            usdt.approve(address(nodeManager), _amount);
            nodeManager.purchaseNode(_amount);
            vm.stopBroadcast();
        }
    }

    // mapping(uint32 => uint32) internal nMap;

    // // forge script MockStakingScript --slow --multi --rpc-url https://go.getblock.asia/cd2737b83bed4b529f2b29001024b1b8 --broadcast --sig "bindUser(uint32,uint32)"
    // function bindUser(uint32 start, uint32 end) public {
    //     initContracts();

    //     uint32 layer = 10;
    //     uint32 layerCount = 5;
    //     uint32 max = 4;
    //     uint32 min = 2;
    //     address rootInviter = 0x9e82E436c3D782d1A8cC41F942FCc6fBc72979b3;
    //     string memory mnemonic = vm.envString("DEV_MNEMONIC");
    //     uint32 startIndex = 10;
    //     uint32 mnemonicIndex = startIndex;
    //     uint256 deployerPrivateKey = vm.envUint("DEV_PRIVATE_KEY");

    //     for (uint32 i = 0; i < layer; i++) {
    //         (uint32[] memory groups, uint32[] memory parents) = randomUser(i, layerCount, min, max);
    //         for (uint32 j = 0; j < groups.length; j++) {
    //             uint32 parentIndex = (i == 0 ? parents[j] : parents[j] + getN(i - 1) * layerCount);
    //             for (uint32 k = 0; k < groups[j]; k++) {
    //                 nMap[mnemonicIndex] = parentIndex;
    //                 mnemonicIndex += 1;
    //             }
    //         }
    //     }

    //     vm.startBroadcast(deployerPrivateKey);

    //     for (uint32 i = start; i < end; i++) {
    //         uint32 mnemonicIndex = i + startIndex;
    //         uint256 userKey = vm.deriveKey(mnemonic, mnemonicIndex);
    //         address user = vm.addr(userKey);

    //         uint32 parentIndex = nMap[mnemonicIndex];
    //         if (mnemonicIndex > 100 && parentIndex == 0) {
    //             continue;
    //         }
    //         uint256 parentKey = vm.deriveKey(mnemonic, parentIndex + startIndex);
    //         address parent = parentIndex == 0 ? rootInviter : vm.addr(parentKey);
    //         nodeManager.bindRootInviter(parent, user);
    //     }
    //     vm.stopBroadcast();
    // }

    // function getN(uint32 i) internal pure returns (uint32) {
    //     uint32 n;
    //     for (uint32 j = 0; j < i; j++) {
    //         n += j + 1;
    //     }
    //     return n;
    // }

    // function randomUser(uint32 layer, uint32 layerCount, uint32 min, uint32 max)
    //     internal
    //     view
    //     returns (uint32[] memory groups, uint32[] memory parents)
    // {
    //     uint32 length = (layer + 1) * layerCount;
    //     uint32 groupLength;
    //     uint32[] memory _groups = new uint32[](length);

    //     while (length > 0) {
    //         uint32 group = random(length, groupLength, max - min) + min;
    //         if (group > length) {
    //             group = length;
    //         }
    //         _groups[groupLength] = group;
    //         groupLength++;
    //         length -= group;
    //     }

    //     groups = new uint32[](groupLength);
    //     parents = new uint32[](groupLength);
    //     for (uint32 i = 0; i < groupLength; i++) {
    //         groups[i] = _groups[i];
    //         (parents[i],) = getRandom(i, layer * layerCount, parents, i, 0);
    //     }
    // }

    // function getRandom(uint32 number, uint32 size, uint32[] memory indexes, uint32 end, uint32 salt)
    //     internal
    //     pure
    //     returns (uint32, uint32)
    // {
    //     if (size == 0) return (0, 0);
    //     uint32 index = random(number, salt, size);
    //     if (isContainUint256(indexes, index, 0, end)) {
    //         return getRandom(number, size, indexes, end, salt + 1);
    //     }
    //     return (index, salt);
    // }

    // function random(uint32 number, uint32 salt, uint32 size) internal pure returns (uint32) {
    //     return uint32(uint256(keccak256(abi.encodePacked(number, salt))) % size);
    // }

    // function isContainUint256(uint32[] memory array, uint32 value, uint32 start, uint32 end)
    //     internal
    //     pure
    //     returns (bool)
    // {
    //     for (uint32 i = start; i < end && i < array.length; i++) {
    //         if (array[i] == value) {
    //             return true;
    //         }
    //     }
    //     return false;
    // }
}
