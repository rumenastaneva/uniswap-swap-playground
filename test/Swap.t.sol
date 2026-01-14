// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {UniV2Swapper} from "../src/UniswapV2Swap.sol";

interface IUniswapV2Router02Like {
    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract SwapTest is Test {
    using SafeERC20 for IERC20;

    address constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

    // USDC-rich mainnet account
    address constant NINO = 0x28C6c06298d514Db089934071355E5743bf21d60;

    UniV2Swapper swap;
    IUniswapV2Router02Like router;

    function _skipIfNotForked() internal {
        if (
            UNIV2_ROUTER.code.length == 0 || USDC.code.length == 0 || USDT.code.length == 0 || WETH.code.length == 0
                || LINK.code.length == 0
        ) {
            vm.skip(true);
        }
    }

    function setUp() public {
        _skipIfNotForked();
        swap = new UniV2Swapper(UNIV2_ROUTER);
        router = IUniswapV2Router02Like(UNIV2_ROUTER);
    }

    // -----------------------------
    // Happy paths
    // -----------------------------

    function testSwapExactInStableCoins() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcUsdt();
        uint256 amountIn = 1_000e6; // 1000 USDC
        uint256 slippageBps = 50;
        uint256 deadline = block.timestamp + 10 minutes;

        // stronger than "balance increased": received >= minOut from quote
        uint256 quotedOut = router.getAmountsOut(amountIn, path)[path.length - 1];
        uint256 expectedMinOut = (quotedOut * (10_000 - slippageBps)) / 10_000;

        IERC20(USDC).forceApprove(address(swap), amountIn);

        uint256 usdtBefore = IERC20(USDT).balanceOf(NINO);

        UniV2Swapper.SwapExactInParams memory p = _exactInParams(amountIn, slippageBps, NINO, deadline, path);
        swap.swapExactIn(p);

        uint256 usdtAfter = IERC20(USDT).balanceOf(NINO);
        uint256 received = usdtAfter - usdtBefore;

        assertGe(received, expectedMinOut);

        vm.stopPrank();
    }

    function testSwapExactOutStableCoins() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcUsdt();
        uint256 amountOut = 1_000e6; // 1000 USDT
        uint256 slippageBps = 50;
        uint256 deadline = block.timestamp + 10 minutes;

        uint256 usdtBefore = IERC20(USDT).balanceOf(NINO);
        uint256 usdcBefore = IERC20(USDC).balanceOf(NINO);

        uint256 quotedIn = router.getAmountsIn(amountOut, path)[0];
        uint256 maxAmountIn = (quotedIn * (10_000 + slippageBps)) / 10_000;

        IERC20(USDC).forceApprove(address(swap), maxAmountIn);

        UniV2Swapper.SwapExactOutParams memory p = _exactOutParams(amountOut, slippageBps, NINO, deadline, path);
        swap.swapExactOut(p);

        uint256 usdtAfter = IERC20(USDT).balanceOf(NINO);
        uint256 usdcAfter = IERC20(USDC).balanceOf(NINO);

        assertEq(usdtAfter - usdtBefore, amountOut);
        assertLe(usdcBefore - usdcAfter, maxAmountIn);

        vm.stopPrank();
    }

    function testSwapExactInStableToNonStable() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcWethLink();
        uint256 amountIn = 1_000e6; // 1000 USDC
        uint256 slippageBps = 50;
        uint256 deadline = block.timestamp + 10 minutes;

        uint256 quotedOut = router.getAmountsOut(amountIn, path)[path.length - 1];
        uint256 expectedMinOut = (quotedOut * (10_000 - slippageBps)) / 10_000;

        IERC20(USDC).forceApprove(address(swap), amountIn);

        uint256 linkBefore = IERC20(LINK).balanceOf(NINO);

        UniV2Swapper.SwapExactInParams memory p = _exactInParams(amountIn, slippageBps, NINO, deadline, path);
        swap.swapExactIn(p);

        uint256 linkAfter = IERC20(LINK).balanceOf(NINO);
        uint256 received = linkAfter - linkBefore;

        assertGe(received, expectedMinOut);

        vm.stopPrank();
    }

    function testSwapExactOutStableToNonStable() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcWethLink();
        uint256 amountOut = 100e18; // 100 LINK
        uint256 slippageBps = 50;
        uint256 deadline = block.timestamp + 10 minutes;

        uint256 linkBefore = IERC20(LINK).balanceOf(NINO);
        uint256 usdcBefore = IERC20(USDC).balanceOf(NINO);

        uint256 quotedIn = router.getAmountsIn(amountOut, path)[0];
        uint256 maxAmountIn = (quotedIn * (10_000 + slippageBps)) / 10_000;

        IERC20(USDC).forceApprove(address(swap), maxAmountIn);

        UniV2Swapper.SwapExactOutParams memory p = _exactOutParams(amountOut, slippageBps, NINO, deadline, path);
        swap.swapExactOut(p);

        uint256 linkAfter = IERC20(LINK).balanceOf(NINO);
        uint256 usdcAfter = IERC20(USDC).balanceOf(NINO);

        assertEq(linkAfter - linkBefore, amountOut);
        assertLe(usdcBefore - usdcAfter, maxAmountIn);

        vm.stopPrank();
    }

    // -----------------------------
    // Reverts / validation
    // -----------------------------

    function testSwapExactIn_RevertOnZeroAmount() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcUsdt();
        UniV2Swapper.SwapExactInParams memory p = _exactInParams(0, 50, NINO, block.timestamp + 10 minutes, path);

        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        swap.swapExactIn(p);

        vm.stopPrank();
    }

    function testSwapExactOut_RevertOnZeroAmount() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcUsdt();
        UniV2Swapper.SwapExactOutParams memory p = _exactOutParams(0, 50, NINO, block.timestamp + 10 minutes, path);

        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        swap.swapExactOut(p);

        vm.stopPrank();
    }

    function testSwapExactIn_RevertOnSlippageTooHigh() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcUsdt();
        uint256 amountIn = 1_000e6;

        IERC20(USDC).forceApprove(address(swap), amountIn);

        UniV2Swapper.SwapExactInParams memory p =
            _exactInParams(amountIn, 10_001, NINO, block.timestamp + 10 minutes, path);

        vm.expectRevert(abi.encodeWithSignature("SlippageTooHigh()"));
        swap.swapExactIn(p);

        vm.stopPrank();
    }

    function testSwapExactOut_RevertOnSlippageTooHigh() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcUsdt();
        UniV2Swapper.SwapExactOutParams memory p =
            _exactOutParams(1_000e6, 10_001, NINO, block.timestamp + 10 minutes, path);

        vm.expectRevert(abi.encodeWithSignature("SlippageTooHigh()"));
        swap.swapExactOut(p);

        vm.stopPrank();
    }

    function testSwapExactIn_RevertOnInvalidPath() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory badPath = new address[](2);
        badPath[0] = USDC;

        uint256 amountIn = 1_000e6;
        IERC20(USDC).forceApprove(address(swap), amountIn);

        UniV2Swapper.SwapExactInParams memory p =
            _exactInParams(amountIn, 50, NINO, block.timestamp + 10 minutes, badPath);

        vm.expectRevert(abi.encodeWithSignature("InvalidPath()"));
        swap.swapExactIn(p);

        vm.stopPrank();
    }

    function testSwapExactOut_RevertOnInvalidPath() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory badPath = new address[](1);
        badPath[0] = USDC;

        UniV2Swapper.SwapExactOutParams memory p =
            _exactOutParams(1_000e6, 50, NINO, block.timestamp + 10 minutes, badPath);

        vm.expectRevert(abi.encodeWithSignature("InvalidPath()"));
        swap.swapExactOut(p);

        vm.stopPrank();
    }

    function testSwapExactIn_RevertOnDeadlineExpired() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcUsdt();
        uint256 amountIn = 1_000e6;
        IERC20(USDC).forceApprove(address(swap), amountIn);

        UniV2Swapper.SwapExactInParams memory p = _exactInParams(amountIn, 50, NINO, block.timestamp - 1, path);

        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired()"));
        swap.swapExactIn(p);

        vm.stopPrank();
    }

    function testSwapExactOut_RevertOnDeadlineExpired() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcUsdt();
        UniV2Swapper.SwapExactOutParams memory p = _exactOutParams(1_000e6, 50, NINO, block.timestamp - 1, path);

        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired()"));
        swap.swapExactOut(p);

        vm.stopPrank();
    }

    function testSwapExactIn_RevertOnInsufficientAllowance() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcUsdt();
        uint256 amountIn = 1_000e6;

        // no approval given
        UniV2Swapper.SwapExactInParams memory p = _exactInParams(amountIn, 50, NINO, block.timestamp + 10 minutes, path);

        vm.expectRevert();
        swap.swapExactIn(p);

        vm.stopPrank();
    }

    function testSwapExactOut_RevertOnInsufficientAllowance() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcUsdt();
        uint256 amountOut = 1_000e6;
        uint256 slippageBps = 50;

        // compute expected maxIn, then approve slightly less
        uint256 quotedIn = router.getAmountsIn(amountOut, path)[0];
        uint256 maxAmountIn = (quotedIn * (10_000 + slippageBps)) / 10_000;

        IERC20(USDC).forceApprove(address(swap), maxAmountIn - 1);

        UniV2Swapper.SwapExactOutParams memory p =
            _exactOutParams(amountOut, slippageBps, NINO, block.timestamp + 10 minutes, path);

        vm.expectRevert();
        swap.swapExactOut(p);

        vm.stopPrank();
    }

    function testSwapExactOut_RespectsMaxInBound() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        address[] memory path = _pathUsdcUsdt();
        uint256 amountOut = 1_000e6;
        uint256 slippageBps = 50;
        uint256 deadline = block.timestamp + 10 minutes;

        uint256 quotedIn = router.getAmountsIn(amountOut, path)[0];
        uint256 maxAmountIn = (quotedIn * (10_000 + slippageBps)) / 10_000;

        IERC20(USDC).forceApprove(address(swap), maxAmountIn);

        uint256 usdcBefore = IERC20(USDC).balanceOf(NINO);

        UniV2Swapper.SwapExactOutParams memory p = _exactOutParams(amountOut, slippageBps, NINO, deadline, path);
        swap.swapExactOut(p);

        uint256 usdcAfter = IERC20(USDC).balanceOf(NINO);
        uint256 spent = usdcBefore - usdcAfter;

        assertLe(spent, maxAmountIn);
        assertGe(spent, quotedIn);

        vm.stopPrank();
    }

    // -----------------------------
    // Helpers
    // -----------------------------

    function _pathUsdcUsdt() internal pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = USDC;
        path[1] = USDT;
    }

    function _pathUsdcWethLink() internal pure returns (address[] memory path) {
        path = new address[](3);
        path[0] = USDC;
        path[1] = WETH;
        path[2] = LINK;
    }

    function _exactInParams(uint256 amountIn, uint256 slippageBps, address to, uint256 deadline, address[] memory path)
        internal
        pure
        returns (UniV2Swapper.SwapExactInParams memory p)
    {
        p = UniV2Swapper.SwapExactInParams({
            amountIn: amountIn,
            slippageBps: slippageBps,
            to: to,
            deadline: deadline,
            path: path
        });
    }

    function _exactOutParams(
        uint256 amountOut,
        uint256 slippageBps,
        address to,
        uint256 deadline,
        address[] memory path
    ) internal pure returns (UniV2Swapper.SwapExactOutParams memory p) {
        p = UniV2Swapper.SwapExactOutParams({
            amountOut: amountOut,
            slippageBps: slippageBps,
            to: to,
            deadline: deadline,
            path: path
        });
    }
}
