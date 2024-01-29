# [TLDR](https://www.tldresear.ch/) Fellowship Project Repo

This repo is exploring how solidity smart contracts are able to take control of their own sequencing via Flashbot's block programming platform [SUAVE](https://suave.flashbots.net/what-is-suave). The PoCs in this repo are building up to a Uniswap v2 AMM which aims to elimintate sandwhich attacks lessen LVR through verified sequencing rules. 

Each PoC will consist of normal solidity smart contracts, to be launched on Goerli testnet, and a SUAVE app (suapp) which will control portions of the sequencing for the smart contracts.


SUAVE PoCs in progress of being written:
- Basic smart contract whose main functionality is only sequence-able by a SUAVE app (“suapp”) [currently being written]
- First swap (‘top of block’) auction for AMM with uniswap v4 hooks [not started]
- AMM which is sequenced with Matheus’s [Greedy Algorithm](https://arxiv.org/pdf/2209.15569.pdf) AMM sequencing rules [not started]
- AMM combining first swap and greedy rules [not started]

poc_only_sequenceable_by_suave

