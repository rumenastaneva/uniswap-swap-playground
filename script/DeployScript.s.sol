// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {UniV2Swapper} from "../src/UniswapV2Swap.sol";

contract DeployScript is Script {
    UniV2Swapper public usdcToUsdtExactInSwap;

    address public uniswapV2Router;

    function setUp() public {
        uniswapV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Uniswap V2 Router
    }

    function run() public {
        vm.startBroadcast();

        usdcToUsdtExactInSwap = new UniV2Swapper(uniswapV2Router);

        vm.stopBroadcast();
    }
}
