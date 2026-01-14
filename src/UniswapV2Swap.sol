// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/console.sol";

interface IUniswapV2Router02 {
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

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract UniV2Swapper {
    using SafeERC20 for IERC20;

    error DeadlineExpired();
    error ZeroAmount();
    error SlippageTooHigh();
    error InvalidPath();

    IUniswapV2Router02 public immutable router;

    constructor(address _router) {
        router = IUniswapV2Router02(_router);
    }

    function swapExactIn(uint256 amountIn, uint256 slippageBps, address to, uint256 deadline, address[] calldata path)
        external
        returns (uint256 amountOut)
    {
        // 1) validate inputs
        if (amountIn == 0) revert ZeroAmount();
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (slippageBps > 10000) revert SlippageTooHigh();
        if (path.length < 2) revert InvalidPath();
        if (to == address(0)) revert InvalidPath();
        if (path[0] == address(0) || path[path.length - 1] == address(0)) revert InvalidPath();

        (address tokenIn, address tokenOut) = determineTokenInAndOut(path);

        // 2) transfer tokens from user to this contract
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // 3) approve router to spend tokens
        IERC20(tokenIn).forceApprove(address(router), amountIn);

        // 4) get quoted amount out
        uint256 quotedAmountOut = getQuotedAmountOut(amountIn, path);
        uint256 minAmountOut = (quotedAmountOut * (10000 - slippageBps)) / 10000;

        // 5) perform the swap
        uint256[] memory amounts = router.swapExactTokensForTokens(amountIn, minAmountOut, path, to, deadline);

        IERC20(tokenIn).forceApprove(address(router), 0);

        return amounts[amounts.length - 1];
    }

    function swapExactOut(uint256 amountOut, address to, uint256 slippageBps, uint256 deadline, address[] calldata path)
        external
        returns (uint256 amountIn)
    {
        if (amountOut == 0) revert ZeroAmount();
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (slippageBps > 10000) revert SlippageTooHigh();
        if (path.length < 2) revert InvalidPath();
        if (to == address(0)) revert InvalidPath();
        if (path[0] == address(0) || path[path.length - 1] == address(0)) revert InvalidPath();

        (address tokenIn, address tokenOut) = determineTokenInAndOut(path);

        // 1) get quoted amount in
        uint256 quotedAmountIn = getQuotedAmountIn(amountOut, path);
        uint256 maxAmountIn = (quotedAmountIn * (10000 + slippageBps)) / 10000;

        // 2) transfer tokens from user to this contract
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), maxAmountIn);

        // 3) approve router to spend tokens
        IERC20(tokenIn).forceApprove(address(router), maxAmountIn);

        // 4) perform the swap
        uint256[] memory amounts = router.swapTokensForExactTokens(amountOut, maxAmountIn, path, to, deadline);

        // 5) refund excess tokens to user
        uint256 actualAmountIn = amounts[0];
        if (maxAmountIn > actualAmountIn) {
            uint256 refundAmount = maxAmountIn - actualAmountIn;
            IERC20(tokenIn).safeTransfer(msg.sender, refundAmount);
        }

        IERC20(tokenIn).forceApprove(address(router), 0);
        return actualAmountIn;
    }

    function determineTokenInAndOut(address[] calldata path)
        internal
        pure
        returns (address tokenIn, address tokenOut)
    {
        tokenIn = path[0];
        tokenOut = path[path.length - 1];

        return (tokenIn, tokenOut);
    }

    function getQuotedAmountOut(uint256 amountIn, address[] calldata path)
        internal
        view
        returns (uint256 quotedAmountOut)
    {
        uint256[] memory amountsOut = router.getAmountsOut(amountIn, path);
        return amountsOut[amountsOut.length - 1];
    }

    function getQuotedAmountIn(uint256 amountOut, address[] calldata path)
        internal
        view
        returns (uint256 quotedAmountIn)
    {
        uint256[] memory amountsIn = router.getAmountsIn(amountOut, path);
        return amountsIn[0];
    }
}
