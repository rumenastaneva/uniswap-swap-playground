// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RumibaToken} from "../src/token.sol";

interface IUniswapV2Router02 {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 r0, uint112 r1, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function balanceOf(address) external view returns (uint256);
}

contract AddLiquidityTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    // Binance hot wallet (USDC-rich)
    address constant WHALE = 0x28C6c06298d514Db089934071355E5743bf21d60;

    address rumi;
    RumibaToken rumba;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        rumi = makeAddr("rumi");

        // Deploy token AS rumi so rumi receives INITIAL_SUPPLY
        vm.startPrank(rumi);
        rumba = new RumibaToken();
        vm.stopPrank();

        // Fund rumi with USDC by impersonating whale
        uint256 usdcAmount = 10_000 * 1e6;

        vm.startPrank(WHALE);
        IERC20(USDC).transfer(rumi, usdcAmount);
        vm.stopPrank();
    }

    function test_addLiquidity_rumba_usdc() public {
        uint256 rumbaAmount = 100_000 * 1e18;
        uint256 usdcAmount = 10_000 * 1e6;

        vm.startPrank(rumi);

        // Approve router to pull tokens from rumi
        rumba.approve(ROUTER, rumbaAmount);
        IERC20(USDC).approve(ROUTER, usdcAmount);

        (uint256 aUsed, uint256 bUsed, uint256 lp) = IUniswapV2Router02(ROUTER).addLiquidity(
            address(rumba), USDC, rumbaAmount, usdcAmount, 0, 0, rumi, block.timestamp + 15 minutes
        );

        vm.stopPrank();

        // Pair should exist now
        address pair = IUniswapV2Factory(FACTORY).getPair(address(rumba), USDC);
        assertTrue(pair != address(0));

        // Rumi should have LP tokens
        uint256 lpBal = IUniswapV2Pair(pair).balanceOf(rumi);
        assertGt(lpBal, 0);
        assertEq(lpBal, lp);

        // Reserves should be non-zero
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();
        assertGt(uint256(r0), 0);
        assertGt(uint256(r1), 0);
    }
}
