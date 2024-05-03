# [TLDR](https://www.tldresear.ch/) Fellowship Project Repo

This repo explores how on-chain solidity smart contracts are able to take control of their own sequencing via Flashbot's block programming platform [SUAVE](https://suave.flashbots.net/what-is-suave) for the sake of capturing their own MEV. This repo contains a proof of concept uniswap v3 pool that auctions off the first swap in the pool per block, enabling the pool to capture some of the LVR arbitrage opportunity which it creates. The auction is written in solidity as a smart contract on Suave and takes advantage of Suave's TEE enabled trusted execution and privacy to make the auction secure. 

The goal of this repo are:
1. Show that smart contract applications are able to sequence themselves for their own benefit.
2. Provide proof-of-concept Suave auction code that is reusable.
3. Start the conversation on why block builders shouldn't exist and why decentralized applications should be able to control their own sequencing. If you find this interesting and want to chat, DM me on [twitter](https://twitter.com/lobstermindset) :).

## System Components

![System Diagram](./solidity_code/assets/system_diagram.png?raw=true "System Diagram")



## How to run
1. Download this repo and init the submodules:
   ```
   git clone https://github.com/Lilyjjo/tldr-research.git
   git submodule update --init --recursive
   ```

2. Setup the needed environment variables in `/solidity_code/.env` from the template `/solidity_code/.sample_env`. 

3. Decide if you want to run locally or on Suave's testnet (testnet is recommended, it's easier than running your own node)
   
   If you want to run locally:
   Download [`suave-geth`](https://github.com/flashbots/suave-geth) and run with: 
   ```
   ./build/bin/geth --suave.dev --syncmode=snap --datadir YOUR_DESIRED_DATADIR_LOCATION --http --http.api eth,net,engine,admin,suavex --http.addr 127.0.0.1 --http.port 8545 --suave.eth.external-whitelist "*"
   ```

4. Setup the L1 contracts
   
   Setting up the L1 contract takes about ~10 minutes to run. It deploys and initializes all of the uniswap code, the L1 auction code, and sets up the swapper and bidders with the needed funds and state to be able to swap the pool's tokens and place bids on the auction contract. All of the bidder/swapper keys in the .env need funds on the target L1 for this to complete. 
   ```
   cd solidity_code
   forge script script/Deployments.s.sol:Deployments --broadcast --legacy -vv --sig "freshL1Contracts(bool,bool)" true true
   ```
5. Put the outputted deployed addresses into `solidity_code/.env`. Those addresses are used for deploying the Suave contracts and by the rust servers.
6. Deploy the Suave Auction contract
   ```
   cd solidity_code
   forge script script/Deployments.s.sol:Deployments --sig "deploySuaveAMMAuction()" --broadcast --legacy -vv
   ```
7. Put the outputted deployed address into `solidity_code/.env`.
8. Initalize the suapp's inital state
   This command is flakey, run until all 3 CCRs are sent.
   ```
   cd rust_interactions
   ./target/debug/auction-cli amm-auction initialize-suapp
   ```
9. Run the block server and watch as `bidder_0` and `swapper_0`'s transactions are eventually included. You can tell successful bundle lands when the used nonce goes up.
   ```
   cd rust_interactions
   ./target/debug/auction-block-listener
   ```

When running an auction through the rust servers, this is what the output looks like on the happy-path:
```
[~~~~  running auction for block: 1472520 ~~~~]
--> sent bid for bidder_0 for: 14
--> sent bid for bidder_1 for: 6
--> sent bid for bidder_2 for: 84
--| triggered auction
Auction Stats
  auctioned block      : 1472520
  last nonce used      : 113
  included swap txns   : 0
  total landed         : 2
  winning bid $        : 14
[~~~~  running auction for block: 1472521 ~~~~]
--> sent bid for bidder_0 for: 92
--> sent bid for bidder_1 for: 16
...
```
The auction is 2nd price, but having the bids included is flakey. The bids are currently stored in the suapp's contract storage instead of in the confidential store. The contract storage only updates when Rigil has blocks produced, so when the auction get triggered it's not guaranteed that the bids have populated the contract storage yet. Fixing this is a TODO in a future version. 

For the same reason the Auction Stats are can report from older auctions. These stats are being pulled from the suapp's contract storage to show what is actually happening inside of the kettle post execution. 
