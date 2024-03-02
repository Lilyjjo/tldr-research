# First Swap Auction
This proof of concept is designed to show a UniswapV3 pool whose first swap of each block is auctioned off. The auction is done in-suave and swaps which are attempted to be sequenced before the auctioned swap will fail. In order to ensure a swap is made, users will need to submit their swap transactions to the Suapp as well. The auction proceeds are sent to the pool's LPs. 

This PoC is designed to be easily re-useable. The auction logic lives in separate contracts and the only modification made to the UniswapV3 pool is calling into the auction code pre swap in a UniswapV4 hook like fashion.

## System Components

![System Diagram](./assets/system_diagram.png?raw=true "System Diagram")

The system is made up of three new smart contracts:
- `AuctionGuard.sol`: L1 contract which provides modifier-like logic to guard a target function's first interaction in a block. In this PoC the guard function, `auctionGuard()`, enforces that the auction winner determined in `AMMAuctionSuapp.sol` is the first swap in the block. `AuctionGuard` also provides the logic for pulling payment from the auction winner, done so in a grief-resistant way.
- `AuctionDeposits.sol`: L1 contract to hold bidder's deposits. This is necessary to ensure that bidders have the funds to cover their bids. Withdrawing from this contract is also guarded to after the auction winner's swap to prevent the auciton winner from pulling their funds. This contract is separated for security purposes. 
- `AMMAuctionSuapp.sol`: Suave contract which runs the auction. There are three user-facing functions to be aware of:
    1. `newPendingTxn()`: Function for swappers and withdrawers to submit their transactions to. These transactions are included in blocks after the first swap.
    2. `newBid()`: Function for bidders to submit their bids to be the first swap on a block. The bidder needs to include their bid, a signed message allowing the `AuctionGuard` to pull at least their bid amount from `AuctionDeposits`, and the desired swap transaction. 
    3. `runAuction()`: Function to run the auction logic. If enough time has passed since the last L1 block, this function determins if a winner for the 2nd price auction exists, creates and signs a transaction for the `AuctionGuard` to pull payments and set the winner, and creates and sends a bundle containing the unlock transaction, the winning first swap transaction, and then the rest of the swapping and withdraw transactions. This auction can be run at most once per block. 

The outputted bundles from the `AMMAuctionSuapp` look as follows:
![System Diagram](./assets/bundle.png?raw=true "System Diagram")

The only change made to the UniswapV3 pool is making a call to the `AuctionGuard:auctionGuard()` logic before every swap. This is comparable to UniswapV4 hooks. 



## User Flows

### Swappers
Swappers will need to submit their signed swap transactions to the `AMMAuctionSuapp` via a Suave confidential compute request (CCR). These transactions will be included, without simulation, after a block's first swap.

### Bidders
In order to bid, bidders will need to deposit funds into the `AuctionDeposits` contract. After this, bidders are able to submit bids to be the first swapper in a block for the target pool by sending a CCR to the `AMMAuctionSuapp`. Bidders need to provide three pieces of information in order to bid:
1. The amount they would like to bid.
2. A EIP-712 signed message giving permission the the `AuctionGuard` to withdraw funds in the target block.
3. The swap transaction itself.
If the swap transaction or the EIP-712 message fail under simulations ran during `runAuction()` then the bid is considered not-valid. A griefing vector exists where the bid winner moves funds before the auction bundle lands. This would cause the rest of the swap transactions to fail to run as the first swap transaction contains the logic to unlock the rest of the block. Bid winners are incentivzed to not do this as they would still be paying for the right to make the first swap. 

### Auction Runner
This is a decentralized system where anyone can initiate the running of the auction. The `AMMAcutionSuapp` is configurable for how far past the last block's timestamp auctions are allowed to conclude. For the Goerli example, we set this to be 5 seconds past. For testing purposes, a mini rust service is provided to trigger the auctions.

## Why this is a PoC
This repo is a proof of concept for the following reasons:
1. Suave is in early developement and does not provide any backwards compatibility guarantees. This means that this code could very well not run in a month or so.
2. This design relies on bundles landing consistently per block. Bundles landing requires that the block proposer is participating in PBS and that the bundle was submitted to and included by the winning block builder. There are not strong guarantees around this today. If enough systems were designed to incentivize the PBS system to have a way to ensure bundle inclusion then this design would be more allowable for prodcution.
3. This PoC will unnecessarily revert swapper's transactions if the bidder's swap transaction fails. This is just bad UX. The current design is resistant to block builders breaking bundles and placing their own swap transactions as the first swap. If it was decided that this is unecessary and that block builders wouldn't do anything to the order of swap transactions in the bundle, then the unlock could happen during the payment pull transaction. The current design doesn't have to trust block builders at all.
4. The auction proceeds aren't being sent to the Uniswap LPs currently. They are just sent to the Suave's auction transaction signing key.
5. There isn't logic to determine how to fund the Suave's auction transaction signing key long term. This cost needs to be factored into the auction somehow.
6. Further research needs to be done on the possiblity of turning off fees for the first swap. Since the bidders are already paying the LPs, turning off the fees for the swap would help set the pool to the CEX prices.

# Interactions

TODO

# Code Notes

### Uniswap Port Notes

This PoC aims to minimally modify the uniswap v3 setup itself. All modifications made to the non-pool components were done in order to get around v3's use of an older compiler and enforcements against modifications of the pool contract itself. 

The uniswap v3 submodules need specific non-default releases. They can be installed via forge:
```
forge install uniswap/v3-core@0.8
forge install uniswap/v3-periphery@0.8
forge install OpenZeppelin/openzeppelin-contracts@release-v4.0
```

List of modifications made to the Uniswap Pool:
- A modifier was added to the swap logic which will cause reverts if a swap has not been made yet and enforces that the first swap was sequenced by the associated Suave auctioned contract.
