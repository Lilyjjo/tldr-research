// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {AMMAuctionSuapp} from "../src/AMMAuctionSuapp.sol";
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
    // (this file): for AMMAuctionSuapp

    /**
     * @notice Pulls environment variables and sets up fork urls.
     * @dev Toggle between Rigil and local devnet with 'USE_RIGIL' in .env
     */
    function setUp() public {
        TestingBaseSetUp();
    }

    /**
     * @notice Deploys the AMMAuctionSuapp contract on Suave.
     * @dev note: Put this deployed address into the TestingBase file
     * @dev command: forge script script/Deployments.s.sol:Deployments --sig "deploySuaveAMMAuction()" --broadcast --legacy -vv
     */
    function deploySuaveAMMAuction() public {
        vm.selectFork(forkIdSuave);
        vm.startBroadcast(privateKeyUserSuave);

        AMMAuctionSuapp ammAuctionSuapp = new AMMAuctionSuapp(
            POOL_DEPLOYED,
            AUCTION_DEPOSITS,
            AUCTION_GUARD,
            chainIdSepolia,
            gasNeededSepoliaPoke
        );
        console2.log("ammAuctionSuapp addresss: ");
        console2.log(address(ammAuctionSuapp));
    }

    /**
     * @notice Deploys and sets up new L1 contracts for testing
     * @dev creates and submits ~30 transactions, will take ~12 minutes to complete
     * @dev note: Put these deployed addresses into the TestingBase file
     * @dev command: forge script script/Deployments.s.sol:Deployments  --broadcast --legacy -vv --verify --sig "freshL1Contracts(bool,bool,bool)" true true true
     */
    function freshL1Contracts(
        bool initPoolState,
        bool enableAuction,
        bool depositBidPaymet
    ) public {
        address admin = addressUserSepolia;
        uint256 adminPk = privateKeyUserSepolia;

        vm.selectFork(forkIdSepolia);
        vm.startBroadcast(adminPk);

        // (1) Auction Deposits
        IAuctionDeposits auctionDeposits = new AuctionDeposits();
        console2.log("auctionDeposits: ");
        console2.log(address(auctionDeposits));

        // (2) Auction Guard
        IAuctionGuard auctionGuard = new AuctionGuard(
            address(auctionDeposits),
            addressStoredSuapp
        );
        console2.log("auctionGuard: ");
        console2.log(address(auctionGuard));
        console2.log("auctionGuard's suapp signing key: ");
        console2.log(addressStoredSuapp);

        // associate the guard in the deposit contract
        auctionDeposits.setAuction(address(auctionGuard));
        vm.stopBroadcast();

        // (3) Modified Uniswap Contracts
        // deploys the tokens, pool factory, swap router, nft manager, and pool contracts
        UniswapBase.DeploymentInfo
            memory deploymentInfo = _deployUniswapConracts(
                address(auctionGuard),
                POOL_FEE,
                admin,
                adminPk,
                forkIdSepolia
            );

        if (initPoolState) {
            // (4) Add state to uniswap contracts, ready for suapp actors
            // note: only does new contract liquidity provisioning, all addresses need to have SepoliaETH already

            // add liquidty to the pool
            _addLiquidity(
                addressUserSepolia2, // liquidity provider
                privateKeyUserSepolia2,
                deploymentInfo
            );
            // give swappers tokens to swap with router
            _fundSwapperApproveSwapRouter(
                addressUserSepolia, // admin
                privateKeyUserSepolia,
                deploymentInfo
            );
            _fundSwapperApproveSwapRouter(
                addressUserSepolia2, // liqudity provider / bidder
                privateKeyUserSepolia2,
                deploymentInfo
            );
            _fundSwapperApproveSwapRouter(
                addressUserSepolia3, // basic swapper
                privateKeyUserSepolia3,
                deploymentInfo
            );
        }
        if (enableAuction) {
            // (5) if to turn auctions on for suapp
            vm.startBroadcast(adminPk);
            auctionGuard.enableAuction(true);
            vm.stopBroadcast();
        }
        if (depositBidPaymet) {
            // (6) if to have bidder place Sepolia eth into the deposit contracts
            vm.startBroadcast(privateKeyUserSepolia2);
            auctionDeposits.deposit{value: .001 ether}();
            vm.stopBroadcast();
        }
    }
}
