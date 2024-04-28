# Rust Auction Crates

These crates are used to interact with the deployed auction AMM contracts. The deployment and initialization code is in the `../solidity_code` folder. 

### `auction-block-listener`
This crate is setup to subscribe to new blocks being produced on the target L1 and to take actions in response. Currently the server is setup to simulate auctions by: 
1. Sending a new CCR bid from `bidder_0` which contains a signed `WithdrawBid` EIP712 message and the swap transaction that the bidder would like to send if they win the bid. The bid is only valid for the next L1 block up for production.
2. Triggering the auction.
3. Printing out the Auction's stats.
   Example stat output:
    ```
    Auction Stats
      auctioned block      : 1437087 // block that was last auctioned (should be the block right after the last L1 block)
      last nonce used      : 58      // which nonce the suapp's signing key is on, useful for knowing if the bundle landed
      included swap txns   : 1       // how many non-bid swap transactions were included in the bundle
      total landed         : 5       // how many non-bid swap transactions have been landed
      winning bid $        : 100     // how much the bidder paid to win the auction (is 2nd price)
    ```
This server is mostly for simulating auctions but can be used in the future just to trigger auctions as needed.

Example invocation:
```
cd rust_interactions
cargo build
./target/debug/auction-block-listener
```

### `auction-cli`
This crate contains commands to initialize the Suapp's confidential store information as well as send auction CCRs.
Commands:
  ```
    Commands:
      auction  // can use to trigger an auction
      bid --bidder <ex"bidder_0">        // send a bid
      swap-tx --swapper <ex"swapper_0">  // send a swap tx
      initialize-suapp  // initialize auction suapp's confidential store
  ```

Example invocation:
```
cd rust_interactions
cargo build
./target/debug/auction-cli amm-auction initialize-suapp
```
### `auction-interface`
This create uses @halo3mic's [suave-alloy](https://github.com/halo3mic/suave-alloy/tree/master/crates/suave-alloy) repo to build and send CCRs to the configured suave http endpoint. 
