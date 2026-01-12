// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {UsdcToUsdtExactInSwap} from "../src/UniswapV2Swap.sol";

// Plan
// Deploy UniswapV2Swap contract
// Create a bot account with Usdc
// Create a user account with usdc
// Make user tx that can be sandwiched
// Have bot do the same swap as the user just before them
// Bot tx goes through
// Price of usdt increases
// User tx goes through and gets less usdt than expected
// Bot sells usdt for profit
// Check balances of user and bot before and after

interface IUniswapV2RouterLike {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract SandwichTest is Test {
    using SafeERC20 for IERC20;

    address constant USER = 0x28C6c06298d514Db089934071355E5743bf21d60; // User address with USDC
    address constant BOT = 0x21a31Ee1afC51d94C2eFcCAa2092aD1028285549; // Bot address with USDC
    address constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    function setUp() public {
        if (USDC.code.length == 0 || USDT.code.length == 0 || UNIV2_ROUTER.code.length == 0) {
            vm.skip(true);
        }
    }

    function testSandwichHurtsUser() public {
        vm.deal(USER, 10 ether);
        vm.deal(BOT, 10 ether);

        uint256 amountInUser = 100e6; // 100 USDC
        uint256 amountInBot = IERC20(USDC).balanceOf(BOT) / 2; // half of bot's USDC
        uint256 slippageBps = 50; // 0.50%
        uint256 deadline = block.timestamp + 10 minutes;

        address[] memory path = pathBuilder(); // [USDC, USDT]

        // baseline on clean state
        uint256 snap = vm.snapshotState();
        uint256 baselineMinOut = minOutFromQuote(amountInUser, path, slippageBps);
        uint256 baselineOut = swapViaRouter(USER, USDC, USDT, amountInUser, baselineMinOut, path, deadline);
        vm.revertToState(snap);

        // "real user": computes minOut BEFORE attack (stale quote)
        uint256 staleMinOut = minOutFromQuote(amountInUser, path, slippageBps);

        // bot front-runs (moves price)
        uint256 botUsdt = swapViaRouter(BOT, USDC, USDT, amountInBot, 0, path, deadline);

        // user executes with staleMinOut AFTER price moved
        uint256 sandwichedOut = swapViaRouter(USER, USDC, USDT, amountInUser, staleMinOut, path, deadline);

        assertLt(sandwichedOut, baselineOut);

        // bot back-runs: USDT -> USDC
        address[] memory backPath = new address[](2);
        backPath[0] = USDT;
        backPath[1] = USDC;

        swapViaRouter(BOT, USDT, USDC, botUsdt, 1, backPath, deadline);
    }

    function minOutFromQuote(uint256 amountIn, address[] memory path, uint256 slippageBps)
        internal
        view
        returns (uint256 minOut)
    {
        uint256 quotedOut = IUniswapV2RouterLike(UNIV2_ROUTER).getAmountsOut(amountIn, path)[path.length - 1];

        // keep (100% - slippage)
        minOut = (quotedOut * (10_000 - slippageBps)) / 10_000;
    }

    function swapViaRouter(
        address actor,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        uint256 deadline
    ) internal returns (uint256 out) {
        vm.startPrank(actor);

        uint256 beforeBal = IERC20(tokenOut).balanceOf(actor);
        IERC20(tokenIn).forceApprove(UNIV2_ROUTER, amountIn);

        IUniswapV2RouterLike(UNIV2_ROUTER).swapExactTokensForTokens(amountIn, amountOutMin, path, actor, deadline);

        uint256 afterBal = IERC20(tokenOut).balanceOf(actor);
        vm.stopPrank();

        out = afterBal - beforeBal;
    }

    function pathBuilder() internal pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = USDC;
        path[1] = USDT;
    }
}
