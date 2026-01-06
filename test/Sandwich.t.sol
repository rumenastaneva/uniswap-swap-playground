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
        vm.deal(USER, 10 ether); // accounts need to have ether in order to pay gas
        vm.deal(BOT, 10 ether);

        UsdcToUsdtExactInSwap swap = new UsdcToUsdtExactInSwap(UNIV2_ROUTER, USDC, USDT);

        uint256 amountInUser = 1_00e6; // 100 USDC
        uint256 amountInBot = 1_000e6; // 1000 USDC
        uint256 slippage = 50; // 0.5% slippage
        uint256 deadline = block.timestamp + 10 minutes;

        // User does their swap
        uint256 baselineOutUser = userSwap(amountInUser, slippage, deadline, swap, USER);
        // Bot does their sandwich swap
        uint256 botSwapAmount = botUsingUniswapRouter(amountInBot, deadline);
        // User does their swap again, but this time after the bot has sandwiched them
        uint256 userUsdtBalanceAfterSandwich = userSwap(amountInUser, slippage, deadline, swap, USER);

        assertLt(userUsdtBalanceAfterSandwich, baselineOutUser);
        // Bot sells usdt back to usdc
        botBackRun(botSwapAmount, deadline);
    }

    function userSwap(uint256 amountIn, uint256 slippage, uint256 deadline, UsdcToUsdtExactInSwap swap, address actor)
        internal
        returns (uint256 usdtGained)
    {
        vm.startPrank(actor);
        uint256 usdtBeforeSwap = IERC20(USDT).balanceOf(actor);

        // user approves our swap contract to swap their usdc
        IERC20(USDC).forceApprove(address(swap), amountIn);

        swap.swapExactIn(amountIn, slippage, actor, deadline);

        uint256 usdtAfterSwap = IERC20(USDT).balanceOf(actor);
        vm.stopPrank();
        usdtGained = usdtAfterSwap - usdtBeforeSwap;
    }

    function pathBuilder() internal pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = USDC;
        path[1] = USDT;
    }

    function botUsingUniswapRouter(uint256 amount, uint256 deadline) internal returns (uint256 usdtGained) {
        vm.startPrank(BOT);
        uint256 usdtBefore = IERC20(USDT).balanceOf(BOT);

        address[] memory path = pathBuilder();
        IERC20(USDC).forceApprove(UNIV2_ROUTER, amount);

        IUniswapV2RouterLike(UNIV2_ROUTER).swapExactTokensForTokens(
            amount,
            0, // accept any amount of usdt, because he wants to not have a fair trade, he wants to sandwich the user and make profit off the price impact
            path,
            BOT,
            deadline
        );

        uint256 usdtAfter = IERC20(USDT).balanceOf(BOT);
        vm.stopPrank();
        usdtGained = usdtAfter - usdtBefore;
    }

    function botBackRun(uint256 usdtAmount, uint256 deadline) internal {
        vm.startPrank(BOT);
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = USDC;

        IERC20(USDT).forceApprove(UNIV2_ROUTER, usdtAmount);

        IUniswapV2RouterLike(UNIV2_ROUTER).swapExactTokensForTokens(
            usdtAmount,
            1, // accept any amount of usdc
            path,
            BOT,
            deadline
        );
        vm.stopPrank();
    }
}
