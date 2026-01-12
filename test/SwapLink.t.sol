// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

import {Test} from "forge-std/Test.sol";

import {UsdcLinkSwap} from "../src/UsdcLinkSwap.sol";

interface IUniswapV2Router02 {
    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract SwapLinkTest is Test {
    using SafeERC20 for IERC20;

    address constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // USDC-rich mainnet account
    address constant NINO = 0x28C6c06298d514Db089934071355E5743bf21d60;

    // LINK-rich mainnet account maybe?
    // or weth rich account to swap weth to link?
    address constant LINK_RICH = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    UsdcLinkSwap swap;
    IUniswapV2Router02 router;

    function setUp() public {
        swap = new UsdcLinkSwap(UNIV2_ROUTER, USDC, LINK, WETH);
        router = IUniswapV2Router02(UNIV2_ROUTER);
    }

    function testSwapExactIn() public {
        vm.deal(NINO, 10 ether);

        vm.startPrank(NINO);

        uint256 amountIn = 1_000e6; // 1000 USDC

        uint256 linkBefore = IERC20(LINK).balanceOf(NINO);

        uint256 slippageBps = 50;

        address[] memory path = new address[](3);
        path[0] = USDC;
        path[1] = WETH;
        path[2] = LINK;

        uint256 quotedAmountOut = router.getAmountsOut(amountIn, path)[1];

        uint256 expectedMinAmountOut = quotedAmountOut * (10_000 - slippageBps) / 10_000;

        IERC20(USDC).forceApprove(address(swap), amountIn);
        swap.swapExactIn(amountIn, slippageBps, NINO, block.timestamp + 10 minutes);

        vm.stopPrank();

        uint256 linkAfter = IERC20(LINK).balanceOf(NINO);

        uint256 linkReceived = linkAfter - linkBefore;

        assertGe(linkReceived, expectedMinAmountOut);
    }

    function testSwapExactOut() public {
        vm.deal(NINO, 10 ether);

        vm.startPrank(NINO);

        uint256 amountOut = 100e18; // 100 LINK

        uint256 linkBefore = IERC20(LINK).balanceOf(NINO);

        uint256 slippageBps = 50;

        address[] memory path = new address[](3);
        path[0] = USDC;
        path[1] = WETH;
        path[2] = LINK;

        uint256 quotedAmountIn = router.getAmountsIn(amountOut, path)[0];

        uint256 expectedMaxAmountIn = quotedAmountIn * (10_000 + slippageBps) / 10_000;

        IERC20(USDC).forceApprove(address(swap), expectedMaxAmountIn);
        swap.swapExactOut(amountOut, NINO, slippageBps, block.timestamp + 10 minutes);

        vm.stopPrank();

        uint256 linkAfter = IERC20(LINK).balanceOf(NINO);

        uint256 linkReceived = linkAfter - linkBefore;

        assertGe(linkReceived, amountOut);
    }

    function testSwapExactIn_RevertOnZeroAmount() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        IERC20(USDC).approve(address(swap), 0);

        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        swap.swapExactIn(0, 50, NINO, block.timestamp + 10 minutes);
    }

    function testSwapExactOut_RevertOnZeroAmount() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        IERC20(USDC).approve(address(swap), 0);

        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        swap.swapExactOut(0, NINO, 50, block.timestamp + 10 minutes);
    }

    function testSwapExactIn_RevertOnSlippageTooHigh() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        IERC20(USDC).approve(address(swap), 1_000e6);

        vm.expectRevert(abi.encodeWithSignature("SlippageTooHigh()"));
        swap.swapExactIn(1_000e6, 15000, NINO, block.timestamp + 10 minutes);
    }

    function testSwapExactOut_RevertOnSlippageTooHigh() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        IERC20(USDC).approve(address(swap), 1_000e6);

        vm.expectRevert(abi.encodeWithSignature("SlippageTooHigh()"));
        swap.swapExactOut(100e18, NINO, 15000, block.timestamp + 10 minutes);
    }

    function testSwapExactIn_RevertWhenDeadlineExpired() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        IERC20(USDC).approve(address(swap), 1_000e6);

        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired()"));
        swap.swapExactIn(1_000e6, 50, NINO, block.timestamp - 1);
    }

    function testSwapExactOut_RevertWhenDeadlineExpired() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        IERC20(USDC).approve(address(swap), 1_000e6);

        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired()"));
        swap.swapExactOut(100e18, NINO, 50, block.timestamp - 1);
    }

    function swapExactIn_RevertWhenUnsufficientAllowance() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        IERC20(USDC).approve(address(swap), 500e6); // approve less than amountIn

        vm.expectRevert();
        swap.swapExactIn(1_000e6, 50, NINO, block.timestamp + 10 minutes);
    }

    function swapExactOut_RevertWhenUnsufficientAllowance() public {
        vm.deal(NINO, 10 ether);
        vm.startPrank(NINO);

        IERC20(USDC).approve(address(swap), 500e6); // approve less than maxAmountIn

        vm.expectRevert();
        swap.swapExactOut(100e18, NINO, 50, block.timestamp + 10 minutes);
    }
}
