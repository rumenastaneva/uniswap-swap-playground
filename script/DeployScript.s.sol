// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {UsdcToUsdtExactInSwap} from "../src/UniswapV2Swap.sol";

contract DeployScript is Script {
    UsdcToUsdtExactInSwap public usdcToUsdtExactInSwap;
    address public uniswapV2Router;
    address public usdc;
    address public usdt;

    function setUp() public {
        uniswapV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Uniswap V2 Router
        usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
    }

    function run() public {
        vm.startBroadcast();

        usdcToUsdtExactInSwap = new UsdcToUsdtExactInSwap(uniswapV2Router, usdc, usdt);

        vm.stopBroadcast();
    }
}
