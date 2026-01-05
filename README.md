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

This mirrors how real MEV bots operate on Ethereum mainnet.

🛠 Tech stack
Solidity ^0.8.20

Foundry

Uniswap V2

OpenZeppelin (IERC20, SafeERC20)

Mainnet fork testing

🚀 Running the project
1. Install dependencies
bash
Copy code
forge install
2. Set up environment
Create a .env file:

env
Copy code
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
3. Run tests on mainnet fork
bash
Copy code
forge test --fork-url $MAINNET_RPC_URL -vv
⚠️ Important notes
This project is educational, not production-ready

It intentionally demonstrates how users can be harmed

MEV protection requires:

private transactions (Flashbots / MEV-Blocker)

or smart routing / aggregators

Solidity alone cannot fully prevent MEV

🧭 Next steps (planned)
Add frontend (React + ethers / viem)

Add quote function for slippage estimation

Show UI-based slippage configuration

Compare public vs private execution paths

Extend to Uniswap V3

📚 Learning goals
This repo exists to build deep intuition, not just working code.

If you understand this project, you understand:

Uniswap swaps

ERC20 approvals

MEV basics

Why frontend & infra matter in DeFi

📝 License
MIT

markdown
Copy code

---

## 🧠 Why this README is structured this way

- **What’s inside** → reviewers instantly know what to look at
- **Concepts covered** → shows *understanding*, not just code
- **How the test works** → proves you understand MEV mechanics
- **Important notes** → shows maturity (not overclaiming security)
- **Next steps** → signals roadmap thinking

This is exactly how strong Web3 repos are written.

---

## ✅ Next suggestions (pick one)

We can now:
1. 🧩 Refactor the contract for **production readiness**
2. 🌐 Start a **frontend swap UI**
3. 🔒 Add **slippage failure tests**
4. 🧠 Write a **blog-style explanation of the sandwich attack**
5. ⚡ Move to **Uniswap V3**

Tell me what you want to do next — you’ve earned it 🚀