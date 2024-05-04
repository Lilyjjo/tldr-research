// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {AuctionSuapp} from "../src/AuctionSuapp.sol";
import {AuctionDeposits} from "../src/AuctionDeposits.sol";
import {AuctionGuard} from "../src/AuctionGuard.sol";
import {IAuctionDeposits} from "../src/interfaces/IAuctionDeposits.sol";
import {IAuctionGuard} from "../src/interfaces/IAuctionGuard.sol";

import {TestingBase} from "./TestingBase.s.sol";
import {UniswapBase} from "./UniswapBase.s.sol";

/**
 * @title Deployment code for L1 and Suave smart contracts
 * @author lilyjjo
 * @dev Need to fill out environment variables in .env
 * @dev Can toggle between Rigil and local devnet with USE_RIGIL env var
 */
contract Deployments is TestingBase, UniswapBase {
    // Test framework is made up in layers
    // (base): setup for testing environment's shared variables and fork initialization
    // (uniswap): code realted to uniV3 initialization and use
    // (this file): for AuctionSuapp

    /**
     * @notice Pulls environment variables and sets up fork urls.
     * @dev Toggle between Rigil and local devnet with 'USE_RIGIL' in .env
     */
    function setUp() public {
        TestingBaseSetUp();
    }

    /**
     * @notice Deploys the AuctionSuapp contract on Suave.
     * @dev note: Put this deployed address into the TestingBase file
     * @dev command: forge script script/Deployments.s.sol:Deployments --sig "deploySuaveAMMAuction()" --broadcast --legacy -vv
     */
    function deploySuaveAMMAuction() public {
        vm.selectFork(forkIdSuave);
        vm.startBroadcast(suave_signer_pk);

        auction_deposits = vm.envAddress("AUCTION_DEPOSITS");
        auction_guard = vm.envAddress("AUCTION_GUARD");
        pool = vm.envAddress("POOL");

        AuctionSuapp ammAuctionSuapp = new AuctionSuapp(
            auction_deposits,
            auction_guard,
            chainIdL1,
            2_000_000 // gas needed, idk might be wrong and/or unused
        );
        console2.log("ammAuctionSuapp addresss: ");
        console2.log(address(ammAuctionSuapp));
    }

    /**
     * @notice Deploys and sets up new L1 contracts for testing
     * @dev creates and submits ~30 transactions, will take ~12 minutes to complete
     * @dev note: Put these deployed addresses into the TestingBase file
     * @dev command: forge script script/Deployments.s.sol:Deployments  --broadcast --legacy -vv --verify --sig "freshL1Contracts(bool,bool)" true true
     */
    function freshL1Contracts(
        bool initPoolState,
        bool depositBidPaymet
    ) public {
        address admin = bidder_0;
        uint256 adminPk = bidder_0_pk;

        vm.selectFork(forkIdL1);
        vm.startBroadcast(adminPk);

        // (1) Auction Deposits
        IAuctionDeposits auctionDeposits = new AuctionDeposits();
        console2.log("auctionDeposits: ");
        console2.log(address(auctionDeposits));

        // (2) Auction Guard
        IAuctionGuard auctionGuard = new AuctionGuard(
            address(auctionDeposits),
            suapp_signer
        );
        console2.log("auctionGuard: ");
        console2.log(address(auctionGuard));
        console2.log("auctionGuard's suapp signing key: ");
        console2.log(suapp_signer);

        // associate the guard in the deposit contract
        auctionDeposits.setAuctionGuard(address(auctionGuard));
        vm.stopBroadcast();

        // (3) Modified Uniswap Contracts
        // deploys the tokens, pool factory, swap router, nft manager, and pool contracts
        UniswapBase.DeploymentInfo
            memory deploymentInfo = _deployUniswapConracts(
                address(auctionGuard),
                POOL_FEE,
                admin,
                adminPk,
                forkIdL1
            );

        if (initPoolState) {
            // (4) Add state to uniswap contracts, ready for suapp actors
            // note: only does new contract liquidity provisioning, all addresses need to have L1ETH already

            // add liquidty to the pool
            _addLiquidity(
                bidder_0, // liquidity provider
                bidder_0_pk,
                deploymentInfo
            );
            // give swappers tokens to swap with router
            _fundSwapperApproveSwapRouter(
                bidder_0,
                bidder_0_pk,
                deploymentInfo
            );
            _fundSwapperApproveSwapRouter(
                bidder_1,
                bidder_1_pk,
                deploymentInfo
            );
            _fundSwapperApproveSwapRouter(
                bidder_2, // liqudity provider / bidder
                bidder_2_pk,
                deploymentInfo
            );
            _fundSwapperApproveSwapRouter(
                swapper_0,
                swapper_0_pk,
                deploymentInfo
            );
            _fundSwapperApproveSwapRouter(
                swapper_1,
                swapper_1_pk,
                deploymentInfo
            );
            _fundSwapperApproveSwapRouter(
                swapper_2,
                swapper_2_pk,
                deploymentInfo
            );
        }
        if (depositBidPaymet) {
            // (6) if to have bidder place L1 eth into the deposit contracts
            vm.startBroadcast(bidder_0_pk);
            auctionDeposits.deposit{value: .001 ether}();
            vm.stopBroadcast();
            vm.startBroadcast(bidder_1_pk);
            auctionDeposits.deposit{value: .001 ether}();
            vm.stopBroadcast();
            vm.startBroadcast(bidder_2_pk);
            auctionDeposits.deposit{value: .001 ether}();
            vm.stopBroadcast();
        }
    }
}
