# [TLDR](https://www.tldresear.ch/) Fellowship Project Repo

This repo is exploring how solidity smart contracts are able to take control of their own sequencing via Flashbot's block programming platform [SUAVE](https://suave.flashbots.net/what-is-suave). The PoCs in this repo are building up to a Uniswap v3 AMM which aims to elimintate sandwhich attacks and lessen LVR through verified sequencing rules. 

Each PoC will consist of normal solidity smart contracts, to be launched on Goerli testnet, and a SUAVE app (suapp) which will control portions of the sequencing for the smart contracts.


SUAVE PoCs in progress of being written:
- Basic smart contract whose main functionality is only sequence-able by a SUAVE app (“suapp”) [⚠️ needs to be rewritten to reflect Suave's [non-consistent and non-synchronous](https://github.com/flashbots/suave-geth/issues/190) off-chain programming model]
- First swap (‘top of block’) auction for AMM for uniswap v3 [currently being written]
- AMM which is sequenced with Matheus’s [Greedy Algorithm](https://arxiv.org/pdf/2209.15569.pdf) AMM sequencing rules [not started]

