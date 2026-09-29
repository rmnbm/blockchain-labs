# ERC20 101

## Overview

This folder contains my solution for the `erc20-101` workshop.

It implements an ERC-20 token with an allow-list and customer tiers, and a Foundry script that deploys it and completes every exercise of the workshop on Sepolia.

## Main Files

- `src/Solution.sol`: ERC-20 token built on OpenZeppelin, minted with the ticker and supply assigned by the evaluator. It adds allow-listing (`setWhitelist`), customer tiers (`setTier`), a free claim for allow-listed addresses (`getToken`) and a paid purchase with a tier-based multiplier (`buyToken`)
- `script/Solve.s.sol`: deploys the token and runs exercises 0 to 9 against the workshop evaluator

## Notes

`Evaluator.sol` and `IExerciceSolution.sol` are copies of the workshop contracts, needed to compile the solution.

## Usage

```bash
git submodule update --init --recursive   # from the repository root
cd erc20-101
forge build
forge script script/Solve.s.sol --rpc-url <SEPOLIA_RPC_URL> --account <your-account> --broadcast
```
