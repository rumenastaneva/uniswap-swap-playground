// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UsdcToUsdtExactInSwap} from "../src/UniswapV2Swap.sol";

interface IUniswapV2Router02 {
    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract SwapTest is Test {
    using SafeERC20 for IERC20;

    address constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // USDC-rich mainnet account
    address constant NINO = 0x28C6c06298d514Db089934071355E5743bf21d60;

    UsdcToUsdtExactInSwap swap;
    IUniswapV2Router02 router;

    function setUp() public {
        swap = new UsdcToUsdtExactInSwap(UNIV2_ROUTER, USDC, USDT);
        router = IUniswapV2Router02(UNIV2_ROUTER);
    }

    function testSwapExactIn() public {
        vm.deal(NINO, 10 ether);

        // impersonate whale
        vm.startPrank(NINO);

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

    function testSwipeExactOut() public {
        vm.deal(NINO, 10 ether);

        vm.startPrank(NINO);

        uint256 amountOut = 1_000e6;
        uint256 slippageBps = 50;
        uint256 deadline = block.timestamp + 10 minutes;
        uint256 usdtBefore = IERC20(USDT).balanceOf(NINO);

        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = USDT;

        uint256[] memory minimumAmountThatNeedsToBeSpent = router.getAmountsIn(amountOut, path);

        uint256 maxAmountIn = (minimumAmountThatNeedsToBeSpent[0] * (10000 + slippageBps)) / 10000;
        IERC20(USDC).forceApprove(address(swap), maxAmountIn);

        swap.swapExactOut(amountOut, NINO, slippageBps, deadline);

        uint256 usdtAfter = IERC20(USDT).balanceOf(NINO);

        assertEq(usdtAfter - usdtBefore, amountOut);
    }

    function testSwapExactIn_RevertOnZeroAmount() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        IERC20(USDC).approve(address(swap), 0);

        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        swap.swapExactIn(0, 50, NINO, block.timestamp + 10 minutes);
    }

    function testSwapExactOut_RerurnsLeftover() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        uint256 amountOut = 1_000e6;
        uint256 slippageBps = 50;
        uint256 deadline = block.timestamp + 10 minutes;

        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = USDT;

        // we need bigger allowance to test leftover
        uint256 maxAmountIn = 2_000e6;

        IERC20(USDC).forceApprove(address(swap), maxAmountIn);

        uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(NINO);

        swap.swapExactOut(amountOut, NINO, slippageBps, deadline);

        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(NINO);
        vm.stopPrank();

        uint256 usdcSpentDuringSwap = usdcBalanceBefore - usdcBalanceAfter;

        uint256 allowedMaxSpend = (maxAmountIn * (10000 + slippageBps)) / 10000;

        assertLt(usdcSpentDuringSwap, allowedMaxSpend);
    }

    function testSwapExactOut_RevertOnDeadlineExpired() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        uint256 amountOut = 1_000e6;
        uint256 slippageBps = 50;
        uint256 deadline = block.timestamp - 1; // already expired

        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired()"));
        swap.swapExactOut(amountOut, NINO, slippageBps, deadline);
    }
}
