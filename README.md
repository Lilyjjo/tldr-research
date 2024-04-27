# [TLDR](https://www.tldresear.ch/) Fellowship Project Repo

This repo explores how on-chain solidity smart contracts are able to take control of their own sequencing via Flashbot's block programming platform [SUAVE](https://suave.flashbots.net/what-is-suave) for the sake of capturing their own MEV. This repo contains a proof of concept uniswap v3 pool that auctions off the first swap in the pool per block, enabling the pool to capture some of the LVR arbitrage opportunity which it creates. The auction is written in solidity as a smart contract on Suave and takes advantage of Suave's TEE enabled trusted execution and privacy to make the auction secure. 

The goal of this repo are:
1. Show that smart contract applications are able to sequence themselves for their own benefit.
2. Provide proof-of-concept Suave auction code that is reusable.
3. Start the conversation on why block builders shouldn't exist and why decentralized applications should be able to control their own sequencing. If you find this interesting and want to chat, DM me on [twitter](https://twitter.com/lobstermindset) :).

## System Components

![System Diagram](./poc_first_swap_auction/assets/system_diagram.png?raw=true "System Diagram")

WIP 🚧👷🏼‍♀️🔨


## How to run
1. Download this repo and init the submodules:
```
git clone https://github.com/Lilyjjo/tldr-research.git
git submodule update --init --recursive
```

2. Setup the needed environment variables in `/poc_first_swap_auction/.env` from the template `/poc_first_swap_auction/.sample_env`. 
- Note: these variables are used by both the rust servers and the Foundry solidity code. Foundry doesn't allow the .env file location to be configured which is why it is in the subdirectory.
- Note: the inputted address/pk pairs need funds on the target L1! 

3. Download [`suave-geth`](https://github.com/flashbots/suave-geth) and run with: 
```
./build/bin/geth --suave.dev --syncmode=snap --datadir YOUR_DESIRED_DATADIR_LOCATION --http --http.api eth,net,engine,admin,suavex --http.addr 127.0.0.1 --http.port 8545 --suave.eth.external-whitelist "*"
```

4. Setup the L1 contracts
Setting up the L1 contract takes about ~10 minutes to run. It deploys and initializes all of the uniswap code, the L1 auction code, and sets up the swapper and bidders with the needed funds and state to be able to swap the pool's tokens and place bids on the auction contract. All of the bidder/swapper keys in the .env need funds on the tar for this to complete. 
```
cd poc_first_swap_auction
forge script script/Deployments.s.sol:Deployments --broadcast --legacy -vv --verify --sig "freshL1Contracts(bool,bool)" true true
```
5. Put the outputted deployed addresses into `poc_first_swap_auction/.env`. Those addresses are used for deploying the Suave contracts and by the rust servers.
6. Deploy the Suave Auction contract
```
cd poc_first_swap_auction
forge script script/Deployments.s.sol:Deployments --sig "deploySuaveAMMAuction()" --broadcast --legacy -vv
```
7. Put the outputted deployed address into `poc_first_swap_auction/.env`.
8. Initalize the suapp's inital state
This command is flakey, run until all 3 CCRs are sent.
```
cd interaction-servers-rust
./target/debug/auction-cli-server amm-auction initialize-suapp
```
9. Run the block server and watch as `bidder_0` and `swapper_0`'s transactions are eventually included. You can tell successful bundle lands when the used nonce goes up.
```
cd interaction-servers-rust
./target/debug/auction-block-server
```
