// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {UniV3GenericTestSetup} from "./utils/UniV3GenericTestSetup.t.sol";
import {IUniswapV3PoolAuctionedFirstSwap} from "../src/uniswap_modifications/IUniswapV3PoolAuctionedFirstSwap.sol";
import {AuctionGuard} from "../src/AuctionGuard.sol";

import "forge-std/console.sol";

/**
 * @title UniswapV3AuctionedFirstSwap
 */
contract UniswapV3AuctionedFirstSwap is UniV3GenericTestSetup {
    address auctioneer;
    address suappKey;
    IUniswapV3PoolAuctionedFirstSwap auctionPool; 

    /**
     * @notice Sets up the pool and initalizes the auction.
     */
    function setUp() public override {
        // setup genric uniswap pool logic
        super.setUp();
        auctionPool = IUniswapV3PoolAuctionedFirstSwap(address(pool)); // recasting for readability 

        // setup auction specific logic
        auctioneer = _nextAddress();
        suappKey = _nextAddress();

        // set pool's auctioneer as owner
        auctionPool.setAuctioneer(auctioneer);

        // set pool's suapp key
        vm.prank(auctioneer);
        auctionPool.setSuappKey(suappKey);

        // turn auctions on 
        vm.prank(suappKey);
        auctionPool.enableAuction(true);

        // advance block, now auctions are enabled
        _incTime();
    }
    
    function test_nonAuctionedFirstSwapShouldFail() public {
        address liquidityProvider = _nextAddress();
        _addLiquidity(liquidityProvider, 10 ether, 10 ether, true);

        address swapper = _nextAddress();
        _swap(swapper, token0, 1 ether, 0, true, ExpectedRevert(true, AuctionGuard.WrongValidSwapBlock.selector));
    }

}
