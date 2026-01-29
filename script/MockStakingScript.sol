// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./InitContract.sol";

// MODE=1 forge script MockStakingScript --slow --multi --rpc-url https://bsc-dataseed.binance.org --broadcast
contract MockStakingScript is InitContract {
    function run() public {
        initContracts();

        // for (uint256 i = 0; i < 10; i++) {
        //     (uint256[] memory groups, uint256[] memory parents) = randomUser(i, 40, 3, 7);
        //     console.log("groups: ===============>", (i + 1) * 40, getN(i) * 40, getN(i + 1) * 40);
        //     for (uint256 j = 0; j < groups.length; j++) {
        //         console.log(groups[j], i == 0 ? parents[j] : parents[j] + getN(i - 1) * 40);
        //     }
        //     console.log("==========================");
        // }

        bindUser();
    }

    function bindUser() internal {
        uint32 layer = 10;
        uint32 layerCount = 40;
        address rootInviter = 0x9e82E436c3D782d1A8cC41F942FCc6fBc72979b3;
        string memory mnemonic = vm.envString("DEV_MNEMONIC");
        uint32 startIndex = 10;
        uint32 mnemonicIndex = startIndex;
        uint256 deployerPrivateKey = vm.envUint("DEV_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        for (uint32 i = 0; i < layer; i++) {
            if (i > 3) {
                continue;
            }

            (uint32[] memory groups, uint32[] memory parents) = randomUser(i, layerCount, 3, 7);
            for (uint32 j = 0; j < groups.length; j++) {
                uint32 parentIndex = i == 0 ? parents[j] : parents[j] + getN(i - 1) * layerCount;
                uint256 parentKey = vm.deriveKey(mnemonic, parentIndex + startIndex);
                address parent = j == 0 ? rootInviter : vm.addr(parentKey);
                for (uint32 k = 0; k < groups[j]; k++) {
                    mnemonicIndex += 1;
                    uint256 userKey = vm.deriveKey(mnemonic, mnemonicIndex);
                    address user = vm.addr(userKey);
                    nodeManager.bindRootInviter(parent, user);
                }
            }
        }
        vm.stopBroadcast();
    }

    function getN(uint32 i) internal pure returns (uint32) {
        uint32 n;
        for (uint32 j = 0; j < i; j++) {
            n += j + 1;
        }
        return n;
    }

    function randomUser(uint32 layer, uint32 layerCount, uint32 min, uint32 max)
        internal
        view
        returns (uint32[] memory groups, uint32[] memory parents)
    {
        uint32 length = (layer + 1) * layerCount;
        uint32 groupLength;
        uint32[] memory _groups = new uint32[](length);

        while (length > 0) {
            uint32 group = random(length, groupLength, max - min) + min;
            if (group > length) {
                group = length;
            }
            _groups[groupLength] = group;
            groupLength++;
            length -= group;
        }

        groups = new uint32[](groupLength);
        parents = new uint32[](groupLength);
        for (uint32 i = 0; i < groupLength; i++) {
            groups[i] = _groups[i];
            (parents[i],) = getRandom(i, layer * layerCount, parents, i, 0);
        }
    }

    function getRandom(uint32 number, uint32 size, uint32[] memory indexes, uint32 end, uint32 salt)
        internal
        pure
        returns (uint32, uint32)
    {
        if (size == 0) return (0, 0);
        uint32 index = random(number, salt, size);
        if (isContainUint256(indexes, index, 0, end)) {
            return getRandom(number, size, indexes, end, salt + 1);
        }
        return (index, salt);
    }

    function random(uint32 number, uint32 salt, uint32 size) internal pure returns (uint32) {
        return uint32(uint256(keccak256(abi.encodePacked(number, salt))) % size);
    }

    function isContainUint256(uint32[] memory array, uint32 value, uint32 start, uint32 end)
        internal
        pure
        returns (bool)
    {
        for (uint32 i = start; i < end && i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }
        }
        return false;
    }
}
