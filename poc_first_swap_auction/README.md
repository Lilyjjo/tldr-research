# First Swap Auction
This proof of concept is designed to show a Uniswap v3 pool whose first swap of each block is auctioned off. The auction is done in-suave and swaps which are attempted to be sequenced before the auctioned swap will fail. In order to ensure a swap is made, users will need to submit their swap transactions to the Suapp as well. The auction proceeds are sent to the pool's LPs. 

This PoC aims to minimally modify the uniswap v3 setup itself. All modifications made to the non-pool components were done in order to get around v3's use of an older compiler and enforcements against modifications of the pool contract itself. 

The uniswap v3 submodules need specific non-default releases. They can be installed via forge:
```
forge install uniswap/v3-core@0.8
forge install uniswap/v3-periphery@0.8
forge install OpenZeppelin/openzeppelin-contracts@release-v4.0
```

List of modifications made to the Uniswap Pool:
- A modifier was added to the swap logic which will cause reverts if a swap has not been made yet and enforces that the first swap was sequenced by the associated Suave auctioned contract.


NOTES:
- None of this is implemented yet, this PoC is a work in progress.
