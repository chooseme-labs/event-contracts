// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@pancake-v2-core/interfaces/IPancakePair.sol";

contract TradeSlippage is OwnableUpgradeable {
    EnumerableSet.AddressSet factories;

    function addFactoryAddresses(address[] memory _addres) public onlyOwner {
        for (uint256 i = 0; i < _addres.length; i++) {
            EnumerableSet.add(factories, _addres[i]);
        }
    }

    function getFactories() public view returns (address[] memory) {
        return EnumerableSet.values(factories);
    }

    function isSwapFactory(address maybePair, address token) public view returns (bool) {
        try this.getFactory(maybePair) returns (address factoryAddress) {
            if (!EnumerableSet.contains(factories, factoryAddress)) {
                return false;
            }
            address token0 = IPancakePair(maybePair).token0();
            address token1 = IPancakePair(maybePair).token1();
            return token0 == token || token1 == token;
        } catch {
            return false;
        }
    }

    function getFactory(address maybePair) public view returns (address) {
        if (!isContract(maybePair)) {
            return address(0);
        }
        try IPancakePair(maybePair).factory() returns (address factoryAddress) {
            return factoryAddress;
        } catch {}
        return address(0);
    }

    function getTradeType(address from, address to, uint256 amount, address token)
        public
        view
        returns (bool isBuy, bool isSell, bool isAddLiquidity, bool isRemoveLiquidity, uint256 rO, uint256 rT)
    {
        bool isFromPair = isSwapFactory(from, token);
        if (isFromPair) {
            (uint256 rOther, uint256 rThis, uint256 balOther, uint256 balThis) = getReserves(from, token);
            isRemoveLiquidity = balOther <= rOther && balThis <= rThis;
            isBuy = !isRemoveLiquidity;

            return (isBuy, isSell, isAddLiquidity, isRemoveLiquidity, rOther, rThis);
        }
        bool isToPair = isSwapFactory(to, token);
        if (isToPair) {
            (uint256 rOther, uint256 rThis, uint256 balOther,) = getReserves(to, token);
            isAddLiquidity = (rOther == 0 || rThis == 0) ? true : balOther >= rOther + (amount * rOther) / rThis;
            isSell = !isAddLiquidity;
            return (isBuy, isSell, isAddLiquidity, isRemoveLiquidity, rOther, rThis);
        }
    }

    function getPairOtherToken(address pairAddr, address token) public view returns (address) {
        IPancakePair pair = IPancakePair(pairAddr);
        address token0 = pair.token0();
        address token1 = pair.token1();

        return token0 == token ? token1 : token0;
    }

    function getReserves(address _pair, address token)
        public
        view
        returns (uint256 rOther, uint256 rThis, uint256 balOther, uint256 balThis)
    {
        IPancakePair iPair = IPancakePair(_pair);
        (uint256 r0, uint256 r1,) = iPair.getReserves();

        address tokenOther = getPairOtherToken(_pair, token);
        if (tokenOther < token) {
            rOther = r0;
            rThis = r1;
        } else {
            rOther = r1;
            rThis = r0;
        }

        balOther = IERC20(tokenOther).balanceOf(_pair);
        balThis = IERC20(token).balanceOf(_pair);
    }

    function isContract(address _addr) public view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
