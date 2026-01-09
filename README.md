# Uniswap V2 Swap Playground (USDC ↔ USDT)

This repository is a **learning playground** for understanding:

- Uniswap V2 swaps
- Exact-in vs exact-out swaps
- Slippage protection
- ERC20 approvals & SafeERC20
- MEV and sandwich attacks
- How sandwich attacks harm users in practice
- How to simulate MEV on a mainnet fork using Foundry

The project is intentionally simple and focused on **core mechanics**, not UI.

---

## 📦 What’s inside

### Smart Contracts
- `UsdcToUsdtExactInSwap.sol`
  - A minimal wrapper around **Uniswap V2 Router**
  - Supports:
    - `swapExactIn` (exact USDC → USDT)
    - slippage protection (basis points)
    - deadline protection
  - Uses `SafeERC20` to safely handle USDC / USDT quirks

### Tests
- `Sandwich.t.sol`
  - Runs on a **mainnet fork**
  - Uses real USDC / USDT liquidity
  - Simulates a **sandwich attack**:
    1. User swaps at fair price (baseline)
    2. Bot front-runs with a large swap
    3. User swaps again at worse price
    4. Assert: user receives **less USDT**
    5. Bot back-runs to realize profit

---

## 🧠 Concepts covered

- Uniswap V2 pricing & price impact
- ERC20 approvals (who approves whom and why)
- Why `amountOutMin = 0` is dangerous for users
- Why attackers can use `amountOutMin = 0`
- Slippage protection using basis points
- MEV sandwich mechanics
- Difference between **public mempool** vs **private execution**
- Why Solidity alone cannot prevent MEV

---

## 🧪 How the sandwich test works (high level)

The test proves harm using this invariant:

```text
user_out_after_sandwich < user_out_baseline
Flow:
User swaps 100 USDC → USDT (baseline)

Bot swaps 1000 USDC → USDT (front-run)

User swaps 100 USDC → USDT again

User receives fewer USDT due to price impact

Bot swaps USDT → USDC (back-run)
```

This mirrors how real MEV bots operate on Ethereum mainnet.

## 🛠 Tech stack
Solidity ^0.8.20

Foundry

Uniswap V2

OpenZeppelin (IERC20, SafeERC20)

Mainnet fork testing

## 🚀 Running the project
1. Install dependencies
forge install
2. Set up environment
Create a .env file:
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
3. Run tests on mainnet fork
forge test --fork-url $MAINNET_RPC_URL

## ⚠️ Important notes
This project is educational, not production-ready

It intentionally demonstrates how users can be harmed

MEV protection requires:

private transactions (Flashbots / MEV-Blocker)

or smart routing / aggregators

Solidity alone cannot fully prevent MEV

## 🧭 Next steps (planned)
Add frontend (React + ethers / viem)

Add quote function for slippage estimation

Show UI-based slippage configuration

Compare public vs private execution paths

Extend to Uniswap V3

## 📚 Learning goals

This repository is a hands-on learning playground with the following goals:

### Smart contract fundamentals
- Understand ERC20 mechanics (balances, allowances, `transferFrom`)
- Build safe wrapper contracts around existing protocols (Uniswap V2)
- Work with non-standard ERC20 tokens (USDC, USDT) using `SafeERC20`
- Implement exact-in and exact-out swap patterns
- Reason about token ownership and approval flows

### Generalized swapping
- Extend the swap contract to work with **any ERC20 token pair**
- Support dynamic swap paths (e.g. tokenA → WETH → tokenB)
- Add quote functions to estimate output before swapping
- Handle token decimals correctly across different tokens
- Design reusable and composable swap interfaces

### Slippage & safety
- Implement configurable slippage protection
- Understand why slippage is a **user responsibility**
- Compare “safe defaults” vs “dangerous defaults”
- Write tests that assert slippage-related invariants

### MEV & protocol behavior
- Understand how Uniswap pricing and price impact work
- Simulate MEV sandwich attacks on a mainnet fork
- Prove user harm with concrete invariants
- Learn why MEV cannot be fully prevented in Solidity
- Explore mitigation strategies (private txs, tighter slippage)

### Testing & tooling
- Use Foundry with mainnet forks
- Impersonate real accounts in tests
- Write scenario-based tests, not just unit tests
- Debug failing mainnet interactions
- Understand remappings and dependency management

### Frontend & dApp integration (next phase)
- Build a simple frontend for swapping tokens
- Learn how a frontend:
  - requests token approvals
  - estimates gas and slippage
  - submits transactions
  - handles pending / failed txs
- Connect frontend to contracts using ethers / viem
- Understand how UX decisions affect user safety

### Full-stack Web3 thinking
- See how smart contracts, frontend, and infra interact
- Understand what must live on-chain vs off-chain
- Learn why many security decisions belong in the frontend
- Build intuition for production-ready DeFi design

This project is intentionally iterative:  
it starts with a single USDC → USDT swap and grows toward a **general-purpose swap dApp** with a strong security mindset.


## 📝 License
MIT