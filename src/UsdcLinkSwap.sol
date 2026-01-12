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

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract UsdcLinkSwap {
    using SafeERC20 for IERC20;

    error DeadlineExpired();
    error ZeroAmount();
    error SlippageTooHigh();

    address public immutable USDC;
    address public immutable LINK;
    address public immutable WETH;
    IUniswapV2Router02 public immutable router;

    constructor(address _router, address _usdc, address _link, address _weth) {
        router = IUniswapV2Router02(_router);
        USDC = _usdc;
        WETH = _weth;
        LINK = _link;
    }

    function swapExactIn(uint256 amountIn, uint256 slippageBps, address to, uint256 deadline)
        external
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (slippageBps > 10000) revert SlippageTooHigh();

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(USDC).forceApprove(address(router), amountIn);

        address[] memory path = new address[](3);
        path[0] = USDC;
        path[1] = WETH;
        path[2] = LINK;

        uint256[] memory quotedAmountsOut = router.getAmountsOut(amountIn, path);

        uint256 slippageAmount = (quotedAmountsOut[2] * slippageBps) / 10000;

        uint256 minAmountOut = quotedAmountsOut[2] - slippageAmount;

        uint256[] memory amounts = router.swapExactTokensForTokens(amountIn, minAmountOut, path, to, deadline);

        return amounts[2];
    }

    function swapExactOut(uint256 amountOut, address to, uint256 slippageBps, uint256 deadline)
        external
        returns (uint256 amountIn)
    {
        if (amountOut == 0) revert ZeroAmount();
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (slippageBps > 10000) revert SlippageTooHigh();

        address[] memory path = new address[](3);
        path[0] = USDC;
        path[1] = WETH;
        path[2] = LINK;

        uint256[] memory quotedIn = router.getAmountsIn(amountOut, path);

        uint256 slippageAmount = (quotedIn[0] * slippageBps) / 10000;

        uint256 maxAmountIn = quotedIn[0] + slippageAmount;

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), maxAmountIn);
        IERC20(USDC).forceApprove(address(router), maxAmountIn);

        uint256[] memory amounts = router.swapTokensForExactTokens(amountOut, maxAmountIn, path, to, deadline);

        // refund leftover USDC
        uint256 refund = maxAmountIn - amounts[0];
        if (refund > 0) {
            IERC20(USDC).safeTransfer(msg.sender, refund);
        }
        IERC20(USDC).forceApprove(address(router), 0);

        return amounts[0];
    }
}
