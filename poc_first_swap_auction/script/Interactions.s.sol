// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {AMMAuctionSuapp} from "../src/AMMAuctionSuapp.sol";
import {AuctionDeposits} from "../src/AuctionDeposits.sol";
import {AuctionGuard} from "../src/AuctionGuard.sol";
import {IAuctionDeposits} from "../src/interfaces/IAuctionDeposits.sol";
import {IAuctionGuard} from "../src/interfaces/IAuctionGuard.sol";

import {CCRForgeUtil} from "./utils/CCRForgeUtil.sol";

import {TestingBase} from "./TestingBase.s.sol";
import {UniswapBase} from "./UniswapBase.s.sol";
import {BlockBuilding} from "./BlockBuilding.s.sol";

/**
 * @title Interactions for AMMAuctionSuapp
 * @author lilyjjo
 * @dev Need to fill out environment variables in .env
 * @dev Can toggle between Rigil and local devnet with USE_RIGIL env var
 * @dev Uses Sepolia as fork for L1
 */
contract Interactions is TestingBase, BlockBuilding, UniswapBase {
    // Test framework is made up in layers
    // (base): setup for testing environment's shared variables and fork initialization
    // (uniswap): code realted to uniV3 initialization and use
    // (builderCode): random code snippets for transaciton and EIP712 logic
    // (this file): for AMMAuctionSuapp

    /**
     * @notice Pulls environment variables and sets up fork urls.
     * @dev Toggle between Rigil and local devnet with 'USE_RIGIL'
     */
    function setUp() public {
        // setup test environment and variables needed for this file
        TestingBaseSetUp();
    }

    /**
     * @notice Deploys the AMMAuctionSuapp contract on Suave.
     * @dev note: Put this deployed address into the TestingBase file
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "deploySuaveAMMAuction()" --broadcast --legacy -vv
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
     * @notice Sets the RPC URL in PokedRelayer used to send transaction to
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "runAuction()" -vv
     */
    function runAuction() public {
        vm.selectFork(forkIdSuave);
        bytes memory confidentialInputs = abi.encodePacked("");
        bytes memory targetCall = abi.encodeWithSignature("runAuction()");
        uint64 nonce = vm.getNonce(addressUserSuave);
        ccrUtil.createAndSendCCR({
            signingPrivateKey: privateKeyUserSuave,
            confidentialInputs: confidentialInputs,
            targetCall: targetCall,
            nonce: nonce,
            to: SUAPP_AMM_DEPLOYED,
            gas: 10000000,
            gasPrice: 1000000000,
            value: 0,
            executionNode: addressKettle,
            chainId: uint256(0x01008C45)
        });
    }

    /**
     * @notice
     * @dev command: forge script script/Interactions.s.sol:Interactions -vv --sig "newPendingSwapTxn(bool)" true
     */
    function newPendingSwapTxn(bool token0) public {
        // (1) build swap transaction to send as confidential information in CCR
        address swapper = addressUserSepolia3;
        uint256 swapperPrivateKey = privateKeyUserSepolia;

        address tokenIn = token0 ? TOKEN_0_DEPLOYED : TOKEN_1_DEPLOYED;

        bytes memory swapTxn = _createSwapTransaction(
            swapper,
            swapperPrivateKey,
            tokenIn,
            .01 ether
        );

        // (2) setup CCR to submit txn to AMM's pending transactions
        bytes memory targetCall = abi.encodeWithSignature("newPendingTxn()");

        console2.log("targetCall: ");
        console2.logBytes(targetCall);
        console2.log("cI:");
        console2.logBytes(swapTxn);
        vm.selectFork(forkIdSuave);
        uint64 nonce = vm.getNonce(addressUserSuave);
        ccrUtil.createAndSendCCR({
            signingPrivateKey: privateKeyUserSuave,
            confidentialInputs: swapTxn,
            targetCall: targetCall,
            nonce: nonce,
            to: SUAPP_AMM_DEPLOYED,
            gas: 2000000,
            gasPrice: 1000000000,
            value: 0,
            executionNode: addressKettle,
            chainId: uint256(0x01008C45)
        });
    }

    /**
     * @notice
     * @dev command: forge script script/Interactions.s.sol:Interactions -vv --sig "newBid()"
     */
    function newBid() public {
        // gather bid's values
        address bidder = addressUserSepolia2;
        uint256 bidderPk = privateKeyUserSepolia2;

        vm.selectFork(forkIdSepolia);
        uint256 blockNumber = block.number + 1;
        uint256 bidAmount = 55;

        console2.log("block number: %d", blockNumber);

        (uint8 v, bytes32 r, bytes32 s) = _createWithdrawEIP712(
            bidder,
            bidderPk,
            blockNumber,
            bidAmount
        );
        bytes memory swapTxn = _createSwapTransaction(
            bidder,
            bidderPk,
            TOKEN_0_DEPLOYED,
            .01 ether
        );

        // create confidential store inputs
        AMMAuctionSuapp.Bid memory bid;
        bid.bidder = bidder;
        bid.blockNumber = blockNumber;
        bid.payment = bidAmount;
        bid.swapTxn = swapTxn;
        bid.v = v;
        bid.r = r;
        bid.s = s;

        bytes memory confidentialInputs = abi.encode(bid); // encode packed?

        bytes memory targetCall = abi.encodeWithSignature(
            "newBid(string)",
            "salt"
        );

        vm.selectFork(forkIdSuave);
        uint64 nonce = vm.getNonce(addressUserSuave);
        ccrUtil.createAndSendCCR({
            signingPrivateKey: privateKeyUserSuave,
            confidentialInputs: confidentialInputs,
            targetCall: targetCall,
            nonce: nonce,
            to: SUAPP_AMM_DEPLOYED,
            gas: 2000000,
            gasPrice: 1000000000,
            value: 0,
            executionNode: addressKettle,
            chainId: uint256(0x01008C45)
        });
    }

    /**
     * @notice Deploys and sets up new L1 contracts for testing
     * @dev creates and submits ~30 transactions, will take a few mintues to complete
     * @dev note: Put these deployed addresses into the TestingBase file
     * @dev command: forge script script/Interactions.s.sol:Interactions  --broadcast --legacy -vv --verify --sig "freshL1Contracts(bool,bool,bool)" true true true
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

        /*

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
        */
    }

    /**
     * @notice
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "setSigningKey()" -vv
     */
    function setSigningKey() public {
        vm.selectFork(forkIdSepolia);
        uint64 nonceStoredSuapp = vm.getNonce(addressStoredSuapp);
        console2.log("suave stored signer nonce:");
        console2.log(nonceStoredSuapp);

        vm.selectFork(forkIdSuave);
        // setup data for confidential compute request
        bytes memory confidentialInputs = abi.encode(privateKeyStoredSuapp);
        bytes memory targetCall = abi.encodeWithSignature(
            "setSigningKey(uint256)",
            nonceStoredSuapp
        );

        uint64 nonce = vm.getNonce(addressUserSuave);
        console2.log("suave address nonce:");
        console2.log(nonce);
        ccrUtil.createAndSendCCR({
            signingPrivateKey: privateKeyUserSuave,
            confidentialInputs: confidentialInputs,
            targetCall: targetCall,
            nonce: nonce,
            to: SUAPP_AMM_DEPLOYED,
            gas: 1000000,
            gasPrice: 1000000000,
            value: 0,
            executionNode: addressKettle,
            chainId: uint256(0x01008C45)
        });
    }

    /**
     * @notice Sets the RPC URL in Auction AMM used to send transaction to
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "setSepoliaUrl()" -vv
     */
    function setSepoliaUrl() public {
        vm.selectFork(forkIdSuave);
        bytes memory confidentialInputs = abi.encodePacked(rpcUrlSepolia);
        bytes memory targetCall = abi.encodeWithSignature("setSepoliaUrl()");
        uint64 nonce = vm.getNonce(addressUserSuave);
        ccrUtil.createAndSendCCR({
            signingPrivateKey: privateKeyUserSuave,
            confidentialInputs: confidentialInputs,
            targetCall: targetCall,
            nonce: nonce,
            to: SUAPP_AMM_DEPLOYED,
            gas: 1000000,
            gasPrice: 1000000000,
            value: 0,
            executionNode: addressKettle,
            chainId: uint256(0x01008C45)
        });
    }

    /**
     * @notice
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "initLastL1Block()" -vv
     */
    function initLastL1Block() public {
        vm.selectFork(forkIdSuave);
        bytes memory confidentialInputs = abi.encodePacked("");
        bytes memory targetCall = abi.encodeWithSignature("initLastL1Block()");
        uint64 nonce = vm.getNonce(addressUserSuave);
        ccrUtil.createAndSendCCR({
            signingPrivateKey: privateKeyUserSuave,
            confidentialInputs: confidentialInputs,
            targetCall: targetCall,
            nonce: nonce,
            to: SUAPP_AMM_DEPLOYED,
            gas: 1000000,
            gasPrice: 1000000000,
            value: 0,
            executionNode: addressKettle,
            chainId: uint256(0x01008C45)
        });
    }

    /**
     * @notice Performs a read on PokeRelayer's storage slots.
     * @dev Useful for reading slot 3 which will hold the set DataIds for the confidential stores
     * @dev command: forge script script/Interactions.s.sol:Interactions -vv --sig "grabSlotSuapp(uint256)" 3
     */
    function grabSlotSuapp(uint256 slot) public {
        vm.selectFork(forkIdSuave);
        bytes32 value = vm.load(SUAPP_AMM_DEPLOYED, bytes32(slot));
        console2.log("slot: %d", slot);
        console2.logBytes32(value);
    }

    /**
     * @notice
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "enableAuctions()" --broadcast --legacy -vv
     */
    function enableAuctions() public {
        vm.selectFork(forkIdSepolia);
        vm.startBroadcast(privateKeyUserSepolia);
        AuctionGuard(AUCTION_GUARD).enableAuction(true);
    }

    function _createSwapTransaction(
        address swapper,
        uint256 swapperPrivateKey,
        address tokenIn,
        uint256 amount
    ) internal returns (bytes memory) {
        UniswapBase.DeploymentInfo memory dInfo = _getUniswapDeploymentInfo();

        bytes memory txnData = _createSwapTranscationData(
            swapper,
            tokenIn,
            amount,
            0,
            dInfo
        );

        vm.selectFork(forkIdSepolia);
        uint64 nonce = vm.getNonce(swapper); // note: will repeat if user already has txns pending

        return
            _signTransaction({
                to: ROUTER_DEPLOYED,
                gas: 100000,
                gasPrice: 100,
                value: 0,
                nonce: nonce,
                targetCall: txnData,
                chainId: chainIdSepolia,
                privateKey: swapperPrivateKey
            });
    }

    function _getUniswapDeploymentInfo()
        internal
        view
        returns (UniswapBase.DeploymentInfo memory dInfo)
    {
        dInfo.token0 = dInfo.token1 = addressUserSepolia;
        dInfo.pool = POOL_DEPLOYED;
        dInfo.nftPositionManager = NPM_DEPLOYED;
        dInfo.factory = FACTORY_DEPLOYED;
        dInfo.swapRouter = ROUTER_DEPLOYED;
        dInfo.admin = addressUserSepolia;
        dInfo.adminPk = privateKeyUserSepolia;
        dInfo.poolFee = POOL_FEE;
        dInfo.forkId = forkIdSepolia;
    }
}
