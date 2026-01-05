// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {UsdcToUsdtExactInSwap} from "../src/UniswapV2Swap.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract SwapTest is Test {
    address constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // USDC-rich mainnet account
    address constant NINO = 0x28C6c06298d514Db089934071355E5743bf21d60;

    function testSwapExactIn() public {
        vm.deal(NINO, 10 ether);

        // impersonate whale
        vm.startPrank(NINO);

        UsdcToUsdtExactInSwap swap = new UsdcToUsdtExactInSwap(
            UNIV2_ROUTER,
            USDC,
            USDT
        );

        uint256 amountIn = 1_000e6; // 1000 USDC

        IERC20(USDC).approve(address(swap), amountIn);

        uint256 usdtBefore = IERC20(USDT).balanceOf(NINO);

        swap.swapExactIn(
            amountIn,
            50, // 0.5% slippage
            NINO,
            block.timestamp + 10 minutes
        );

        uint256 usdtAfter = IERC20(USDT).balanceOf(NINO);

        assertGt(usdtAfter, usdtBefore);
    }
}
