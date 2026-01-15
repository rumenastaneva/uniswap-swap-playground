// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "forge-std/console.sol";

contract RumibaToken is ERC20, Ownable {
    error ExceedsMaxSupply(uint256 requested, uint256 available);

    uint256 public immutable INITIAL_SUPPLY = 1_000_000e18; // 1 million tokens
    uint256 public immutable MAX_SUPPLY = 10_000_000e18; // 10 million tokens

    constructor() ERC20("RumbaToken", "RUMBA") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY); // Mint 1 million tokens to the deployer
    }

    function mint(address to, uint256 amount) external onlyOwner {
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert ExceedsMaxSupply({requested: amount, available: MAX_SUPPLY - totalSupply()});
        }
        _mint(to, amount);
    }
}
