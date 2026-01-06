// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/console.sol";

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsIn(
        uint256 amountOut,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

contract UsdcToUsdtExactInSwap {
    using SafeERC20 for IERC20;

    error DeadlineExpired();
    error ZeroAmount();
    error SlippageTooHigh();

    address public immutable USDC;
    address public immutable USDT;
    IUniswapV2Router02 public immutable router;
    constructor(address _router, address _usdc, address _usdt) {
        router = IUniswapV2Router02(_router);
        USDC = _usdc;
        USDT = _usdt;
    }

    /// @notice Swap exact USDC in for USDT out (slippage protected by minOut)
    /// @param amountIn exact amount of USDC the user spends (USDC has 6 decimals)
    /// @param slippageBps maximum slippage allowed (in basis points, 10000 = 100%)
    /// @param to receiver of USDT (usually msg.sender)
    /// @param deadline unix timestamp after which the tx reverts
    function swapExactIn(
        uint256 amountIn,
        uint256 slippageBps,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        // 1) validate inputs
        if (amountIn == 0) revert ZeroAmount();
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (slippageBps > 10000) revert SlippageTooHigh();

        // 2) pull USDC from user
        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amountIn);

        // 3) approve router
        IERC20(USDC).forceApprove(address(router), amountIn);

        // 4) build path
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = USDT;

        uint256 minAmountOut = (amountIn * (10000 - slippageBps)) / 10000; // calculate min amount out based on slippage

        // 5) call router
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            to,
            deadline
        );
        // 6) return final output
        return amounts[1];
    }

    function swapExactOut(
        uint256 amountOut,
        address to,
        uint256 slippageBps,
        uint256 deadline
    ) external returns (uint256 amountIn) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (slippageBps > 10000) revert SlippageTooHigh();

        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = USDT;

        uint256[] memory minimumAmountThatNeedsToBeSpent = router.getAmountsIn(
            amountOut,
            path
        );
        uint256 amountInMax = (minimumAmountThatNeedsToBeSpent[0] *
            (10000 + slippageBps)) / 10000;

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amountInMax);

        IERC20(USDC).forceApprove(address(router), amountInMax);

        uint256[] memory amounts = router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            to,
            deadline
        );

        uint256 leftover = amountInMax - amounts[0];
        if (leftover > 0) {
            IERC20(USDC).safeTransfer(msg.sender, leftover);
        }
        IERC20(USDC).forceApprove(address(router), 0);

        return amounts[0];
    }
}
