// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../interfaces/event/IOrderBookManager.sol";
import "../../interfaces/event/IOrderBookPod.sol";

abstract contract OrderBookManagerStorage is IOrderBookManager {
    address public executor;

    uint256[99] private __gap;
}
