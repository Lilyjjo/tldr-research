# Interaction Servers written in Rust

These crates are used to run servers for interacting with the suapps.

## Servers
### PoC First Swap Auction
This PoC needs two servers: one for listening for new Sepolia block to be produced (for the sake of triggering an auction) and a cli for interacting with the Suapps otherwise. 

Originally I wrote all of the suapp interaction logic in Foundry Solidity but that was a bad idea because:
- Foundry doesn't support custom transaction types (re: Suave's Confidential Compute Requests).
- I needed a command line interface to make sending the suapp commands easier than what Foundry scripting allows for.

These servers utilize Alloy for interacting with Suave and whatever chatgpt recommended otherwise. 

## Repo commands

Format code: 
```
## if need to install specific nightly commit:
rustup toolchain install nightly-2024-02-07-aarch64-apple-darwin 
cargo +nightly-2024-02-07 fmt --all
```
