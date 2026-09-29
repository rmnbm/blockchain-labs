# ERC721 101

## Overview

This folder contains my solution for the `erc721-101` workshop.

It implements `MyCryptoZoo`, an ERC-721 collection where registered breeders declare animals as NFTs, sell them and breed them, and a Foundry script that completes every exercise of the workshop on Sepolia.

## Main Files

- `src/MyCryptoZoo.sol`: ERC-721 Enumerable contract built on OpenZeppelin, with:
  - paid breeder registration
  - animals with on-chain characteristics (name, sex, legs, wings)
  - burning of dead animals
  - a built-in marketplace (`offerForSale`, `buyAnimal`)
  - paid reproduction between animals, with parent tracking
- `script/Solve.s.sol`: deploys the contract and runs exercises 1 to 7 against the two workshop evaluators

## Notes

`IExerciceSolution.sol` is the interface required by the workshop evaluators.

## Usage

```bash
git submodule update --init --recursive   # from the repository root
cd erc721-101
forge build
forge script script/Solve.s.sol --rpc-url <SEPOLIA_RPC_URL> --broadcast
```

The script reads the deployer key from the `PRIVATE_KEY` environment variable.
