// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {UniV3GenericTestSetup} from "./utils/UniV3GenericTestSetup.t.sol";
import {IUniswapV3PoolAuctioned} from "../src/interfaces/IUniswapV3PoolAuctioned.sol";
import {ISwapRouter} from "v3-periphery-fixed/interfaces/ISwapRouter.sol";
import {IAuctionGuard} from "../src/interfaces/IAuctionGuard.sol";
import {IAuctionDeposits} from "../src/interfaces/IAuctionDeposits.sol";
import {AuctionGuard} from "../src/AuctionGuard.sol";
import {AuctionDeposits} from "../src/AuctionDeposits.sol";

import "forge-std/console.sol";

/**
 * @title UniswapV3AuctionedFirstSwap
 */
contract UniswapV3AuctionedFirstSwap is UniV3GenericTestSetup {
    address adminAuctionGuard =
        address(0x5434073107Ef5dc9Ac1b36D101eEa812DBE0bF31);
    address suappKey = address(0x033FF54B2A7C70EeCB8976d910C055fAf952078a);
    address admin = address(0x5434073107Ef5dc9Ac1b36D101eEa812DBE0bF31);
    address addressUserL1 = address(0x5434073107Ef5dc9Ac1b36D101eEa812DBE0bF31);
    address addressUserL12 =
        address(0x88c75B9Ab2bDD3bE7E24ECe226BE4279746aeD81);
    address addressUserL13 =
        address(0xa6d33de6F072281de6884862A778ee03Ef5c3aAc);

    IAuctionDeposits auctionDeposits;
    IAuctionGuard auctionGuard;
    IUniswapV3PoolAuctioned auctionPool;

    UniV3GenericTestSetup.DeploymentInfo dInfo;

    /**
     * @notice Sets up the pool and initalizes the auction.
     */
    function setUp() public {
        vm.chainId(17000);
        // setup auction guard and deposits
        bool enableAuction = true;
        bool depositBidPaymet = true;
        bool initPoolState = true;

        vm.deal(adminAuctionGuard, 10 ether);
        vm.deal(suappKey, 10 ether);
        vm.deal(admin, 10 ether);
        vm.deal(addressUserL1, 10 ether);
        vm.deal(addressUserL12, 10 ether);
        vm.deal(addressUserL13, 10 ether);

        vm.startPrank(admin);

        // (1) Auction Deposits
        auctionDeposits = new AuctionDeposits();
        console.log("auctionDeposits: ");
        console.log(address(auctionDeposits));

        // (2) Auction Guard
        auctionGuard = new AuctionGuard(address(auctionDeposits), suappKey);

        // associate the guard in the deposit contract
        auctionDeposits.setAuctionGuard(address(auctionGuard));
        vm.stopPrank();

        // (3) Modified Uniswap Contracts
        // deploys the tokens, pool factory, swap router, nft manager, and pool contracts
        dInfo = _deployUniswapConracts(address(auctionGuard), 3000, admin);

        if (initPoolState) {
            // (4) Add state to uniswap contracts, ready for suapp actors
            // note: only does new contract liquidity provisioning, all addresses need to have L1ETH already

            // add liquidty to the pool
            _addLiquidity(
                addressUserL12, // liquidity provider
                dInfo
            );
            // give swappers tokens to swap with router
            _fundSwapperApproveSwapRouter(
                addressUserL1, // admin
                dInfo
            );
            _fundSwapperApproveSwapRouter(
                addressUserL12, // liqudity provider / bidder
                dInfo
            );
            _fundSwapperApproveSwapRouter(
                addressUserL13, // basic swapper
                dInfo
            );
        }
        if (enableAuction) {
            // (5) if to turn auctions on for suapp
            vm.prank(admin);
            auctionGuard.enableAuction(true);
        }
        if (depositBidPaymet) {
            // (6) if to have bidder place L1 eth into the deposit contracts
            //vm.startBroadcast(privateKeyUserL12);
            vm.prank(addressUserL12);
            auctionDeposits.deposit{value: .001 ether}();
        }
    }

    function test_nonAuctionedFirstSwapShouldFail() public {
        ISwapRouter.ExactInputSingleParams memory swapParams;
        swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: dInfo.token0,
            tokenOut: dInfo.token1,
            fee: dInfo.poolFee,
            recipient: addressUserL13,
            deadline: block.timestamp + 10000,
            amountIn: 10,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // see fine on block that auctions were enabled on (makes ok to swap)
        vm.prank(addressUserL13);
        dInfo.swapRouter.exactInputSingle(swapParams);

        // see not fine on next block
        vm.roll(block.number + 1);
        vm.expectRevert();
        dInfo.swapRouter.exactInputSingle(swapParams);
    }
}
