# ERC4626 101

## Overview

This folder contains my solution for the `erc4626-101` workshop.

It implements a tokenized yield vault following the ERC-4626 standard, and a contract that completes every exercise of the workshop in a single transaction on Sepolia.

## Main Files

- `src/MyVault.sol`: ERC-4626 vault built on OpenZeppelin, deployed with the name and symbol assigned by the evaluator
- `src/AllInOneSolution.sol`: deploys the vault and runs all the evaluator checks (deposit, mint, withdraw, redeem, previews, yield, max functions)
- `script/Deploy.s.sol`: deploys a standalone vault
- `script/DeployAllInOne.s.sol`: deploys the all-in-one solution

## Notes

`Evaluator.sol`, `ERC4626_101.sol`, `MockUnderlying.sol` and the interface files are copies of the workshop contracts, needed to compile the solution.

## Usage

```bash
git submodule update --init --recursive   # from the repository root
cd erc4626-101
forge build
forge script script/DeployAllInOne.s.sol --rpc-url sepolia --broadcast
```

`--rpc-url sepolia` reads the `SEPOLIA_RPC_URL` environment variable.
