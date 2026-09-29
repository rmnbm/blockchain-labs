# ⛓️ Blockchain Labs

My solutions to a series of hands-on Ethereum workshops, from basic tokens to DeFi integrations, all completed on the **Sepolia** testnet.

Each workshop comes with an on-chain **evaluator** contract: a solution is validated by deploying contracts and calling the evaluator, which checks each exercise and awards on-chain marks.

📘 **Workshop statements:** [Elli610/Blockchain-101](https://github.com/Elli610/Blockchain-101)

Each folder below is a self-contained project with its own README.

## Workshops

| # | Solution | Statement | Topic | Key concepts | Tooling |
|---|----------|-----------|-------|--------------|---------|
| 1 | [ERC20 101](./erc20-101) | [erc20-101](https://github.com/Elli610/Blockchain-101/tree/main/workshops/solidity/erc20-101) | Fungible tokens | ERC-20 standard, allow-listing, tiered token sale | Foundry |
| 2 | [ERC20 102](./erc20-102) | [erc20-102](https://github.com/Elli610/Blockchain-101/tree/main/workshops/solidity/erc20-102) | Token deposits | Deposit / withdraw flows, receipt token | Hardhat, TypeScript |
| 3 | [ERC721 101](./erc721-101) | [erc721-101](https://github.com/Elli610/Blockchain-101/tree/main/workshops/solidity/erc721-101) | NFTs | ERC-721 Enumerable, NFT marketplace, breeding | Foundry |
| 4 | [ERC4626 101](./erc4626-101) | [erc4626-101](https://github.com/Elli610/Blockchain-101/tree/feat/erc4626-101/workshops/solidity/erc4626-101) | Tokenized vaults | ERC-4626, shares vs assets, yield | Foundry |
| 5 | [AMM 101](./amm-101) | [amm-101](https://github.com/Elli610/Blockchain-101/tree/main/workshops/solidity/amm-101) | Decentralized exchange | Uniswap v4 liquidity positions, Permit2 | Hardhat, TypeScript |
| 6 | [Lending 101](./lending-101) | [lending-101](https://github.com/Elli610/Blockchain-101/tree/main/workshops/solidity/lending-101) | Lending protocol | Aave v3 supply / borrow, flash loans | Foundry |

## Highlights

- **ERC20 101**: ERC-20 token deployed with the ticker and supply assigned by the evaluator, with an allow-list and customer tiers controlling free claims and paid purchases. A single script completes exercises 0 to 9.
- **ERC20 102**: deposit and withdrawal contract that issues its own receipt token to track user positions.
- **ERC721 101**: `MyCryptoZoo`, an NFT collection where registered breeders declare animals with on-chain characteristics, sell them on a built-in marketplace and breed them. Exercises 1 to 7 across two evaluators.
- **ERC4626 101**: yield vault built on OpenZeppelin's ERC-4626, plus an all-in-one contract that runs every evaluator check (deposit, mint, withdraw, redeem, previews, yield, max functions) in a single transaction.
- **AMM 101**: custom workshop token and liquidity management on Uniswap v4 through the Position Manager and Permit2.
- **Lending 101**: integration with Aave v3 on Sepolia, exercises 1 to 8 (the flash-loan exercise 9 cannot be completed as published because of an issue in the workshop evaluator).

## Tech stack

- **Language:** Solidity
- **Tooling:** Foundry, Hardhat / TypeScript
- **Libraries:** OpenZeppelin, Uniswap v4, Aave v3
- **Network:** Sepolia testnet

## Getting started

```bash
git clone --recurse-submodules https://github.com/rmnbm/blockchain-labs.git
```

Then follow the README of the workshop you want to explore.

## Related project

- [daily-headline](https://github.com/rmnbm/daily-headline): a dynamic NFT updated every day with the New York Times headline and an AI-generated image (Solidity, Foundry, Python, IPFS, GitHub Actions).

## Credits

Workshop statements and evaluator contracts come from [Blockchain-101](https://github.com/Elli610/Blockchain-101), some of them originally created by [Henri Lieutaud](https://github.com/l-henri). The solutions in this repository are my own.
