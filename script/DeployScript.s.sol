// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {UsdcToUsdtExactInSwap} from "../src/UniswapV2Swap.sol";
import {UsdcLinkSwap} from "../src/UsdcLinkSwap.sol";

contract DeployScript is Script {
    UsdcToUsdtExactInSwap public usdcToUsdtExactInSwap;
    UsdcLinkSwap public usdcLinkSwap;

    address public uniswapV2Router;
    address public usdc;
    address public usdt;
    address public link;
    address public weth;

    function setUp() public {
        uniswapV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Uniswap V2 Router
        usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        link = 0x514910771AF9Ca656af840dff83E8264EcF986CA; // LINK
        weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    }

    function run() public {
        vm.startBroadcast();

        // deploy UsdcToUsdtExactInSwap contract when we want to use usdc-usdt pair;
        usdcToUsdtExactInSwap = new UsdcToUsdtExactInSwap(uniswapV2Router, usdc, usdt);

        // deploy UsdcLinkSwap contract when we want to use usdc-link pair;
        usdcLinkSwap = new UsdcLinkSwap(uniswapV2Router, usdc, link, weth);

        vm.stopBroadcast();
    }
}
