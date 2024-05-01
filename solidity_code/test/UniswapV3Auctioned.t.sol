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
    address auctioneer = address(0x5434073107Ef5dc9Ac1b36D101eEa812DBE0bF31);
    address suappKey = address(0x033FF54B2A7C70EeCB8976d910C055fAf952078a);
    address admin = address(0x5434073107Ef5dc9Ac1b36D101eEa812DBE0bF31);
    address addressUserSepolia =
        address(0x5434073107Ef5dc9Ac1b36D101eEa812DBE0bF31);
    address addressUserSepolia2 =
        address(0x88c75B9Ab2bDD3bE7E24ECe226BE4279746aeD81);
    address addressUserSepolia3 =
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

        vm.deal(auctioneer, 10 ether);
        vm.deal(suappKey, 10 ether);
        vm.deal(admin, 10 ether);
        vm.deal(addressUserSepolia, 10 ether);
        vm.deal(addressUserSepolia2, 10 ether);
        vm.deal(addressUserSepolia3, 10 ether);

        vm.startPrank(admin);

        // (1) Auction Deposits
        auctionDeposits = new AuctionDeposits();
        console.log("auctionDeposits: ");
        console.log(address(auctionDeposits));

        // (2) Auction Guard
        auctionGuard = new AuctionGuard(address(auctionDeposits), suappKey);

        // associate the guard in the deposit contract
        auctionDeposits.setAuction(address(auctionGuard));
        vm.stopPrank();

        // (3) Modified Uniswap Contracts
        // deploys the tokens, pool factory, swap router, nft manager, and pool contracts
        dInfo = _deployUniswapConracts(address(auctionGuard), 3000, admin);

        if (initPoolState) {
            // (4) Add state to uniswap contracts, ready for suapp actors
            // note: only does new contract liquidity provisioning, all addresses need to have SepoliaETH already

            // add liquidty to the pool
            _addLiquidity(
                addressUserSepolia2, // liquidity provider
                dInfo
            );
            // give swappers tokens to swap with router
            _fundSwapperApproveSwapRouter(
                addressUserSepolia, // admin
                dInfo
            );
            _fundSwapperApproveSwapRouter(
                addressUserSepolia2, // liqudity provider / bidder
                dInfo
            );
            _fundSwapperApproveSwapRouter(
                addressUserSepolia3, // basic swapper
                dInfo
            );
        }
        if (enableAuction) {
            // (5) if to turn auctions on for suapp
            vm.prank(admin);
            auctionGuard.enableAuction(true);
        }
        if (depositBidPaymet) {
            // (6) if to have bidder place Sepolia eth into the deposit contracts
            //vm.startBroadcast(privateKeyUserSepolia2);
            vm.prank(addressUserSepolia2);
            auctionDeposits.deposit{value: .001 ether}();
        }
    }

    function test_nonAuctionedFirstSwapShouldFail() public {
        ISwapRouter.ExactInputSingleParams memory swapParams;
        swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: dInfo.token0,
            tokenOut: dInfo.token1,
            fee: dInfo.poolFee,
            recipient: addressUserSepolia3,
            deadline: block.timestamp + 10000,
            amountIn: 10,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        vm.prank(addressUserSepolia3);
        dInfo.swapRouter.exactInputSingle(swapParams);
    }

    function test_debugAuctionDeposits() public {
        console.log("aD addy:");
        console.log(address(auctionDeposits));
        address bidder = addressUserSepolia2;
        uint256 blockNumber = 10;
        uint256 amount = 10;
        uint8 v = 27;
        bytes32 r = 0xe2ab6d24ee13759f3b9058b3ce4ad144575464679dc05345b03caed45a2728fc;
        bytes32 s = 0x5a01b97e514eb644537009d61c24a05636e593fc911dd83ed6a175e59b495f59;
        auctionDeposits.withdrawBid(bidder, blockNumber, amount, v, r, s);
    }
}
