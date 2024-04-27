# [TLDR](https://www.tldresear.ch/) Fellowship Project Repo

This repo explores how on-chain solidity smart contracts are able to take control of their own sequencing via Flashbot's block programming platform [SUAVE](https://suave.flashbots.net/what-is-suave) for the sake of capturing their own MEV. This repo contains a proof of concept uniswap v3 pool that auctions off the first swap in the pool per block, enabling the pool to capture some of the LVR arbitrage opportunity which it creates. The auction is written in solidity as a smart contract on Suave and takes advantage of Suave's TEE enabled trusted execution and privacy to make the auction secure. 

The goal of this repo are:
1. Show that smart contract applications are able to sequence themselves for their own benefit.
2. Provide proof-of-concept Suave auction code that is reusable.
3. Start the conversation on why block builders shouldn't exist and why decentralized applications should be able to control their own sequencing. If you find this interesting and want to chat, DM me on [twitter](https://twitter.com/lobstermindset) :).

## System Components

![System Diagram](./poc_first_swap_auction/assets/system_diagram.png?raw=true "System Diagram")

WIP 🚧👷🏼‍♀️🔨
