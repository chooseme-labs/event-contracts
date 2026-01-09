// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@pancake-v2-periphery/interfaces/IPancakeRouter02.sol";

library SwapHelper {
    /**
     * @dev Swap tokens on PancakeSwap V2 router
     * @param router PancakeSwap V2 router address
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amount Amount of input token to swap
     * @param to Address to receive output tokens
     * @return Amount of output tokens received
     */
    function swapV2(address router, address tokenIn, address tokenOut, uint256 amount, address to) internal returns (uint256) {
        uint256 balOld = IERC20(tokenOut).balanceOf(to);
        IERC20(tokenIn).approve(router, amount);
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        IPancakeRouter02(router)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 1, path, to, block.timestamp + 20);
        uint256 balNew = IERC20(tokenOut).balanceOf(to);
        return balNew - balOld;
    }

    /**
     * @dev Add liquidity to PancakeSwap V2 pool
     * @param router PancakeSwap V2 router address
     * @param token0 First token address
     * @param token1 Second token address
     * @param amount Total amount of token0 to use (50% will be swapped to token1)
     * @param to Address to receive LP tokens
     * @return liquidityAdded Amount of LP tokens minted
     * @return amount0Used Amount of token0 used
     * @return amount1Used Amount of token1 used
     */
    function addLiquidityV2(
        address router,
        address token0,
        address token1,
        uint256 amount,
        address to
    ) internal returns (uint256 liquidityAdded, uint256 amount0Used, uint256 amount1Used) {
        uint token0Amount = amount / 2;
        uint token1Amount = SwapHelper.swapV2(router, token0, token1, token0Amount, address(this));
        IERC20(token0).approve(router, token0Amount);
        IERC20(token1).approve(router, token1Amount);
        (amount0Used,amount1Used, liquidityAdded) =
            IPancakeRouter02(router).addLiquidity(token0, token1, token0Amount, token1Amount, 0, 0, to, block.timestamp);
    }
}
