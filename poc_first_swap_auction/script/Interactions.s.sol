// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Transactions} from "suave-std/Transactions.sol";
import {Suave} from "suave-std/suavelib/Suave.sol";
import {LibString} from "../lib/suave-std/lib/solady/src/utils/LibString.sol";

import {AMMAuctionSuapp} from "../src/AMMAuctionSuapp.sol";
import {AuctionDeposits} from "../src/AuctionDeposits.sol";
import {AuctionGuard} from "../src/AuctionGuard.sol";
import {IAuctionDeposits} from "../src/IAuctionDeposits.sol";
import {IAuctionGuard} from "../src/IAuctionGuard.sol";

import {SigUtils} from "./utils/EIP712Helpers.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

import {IUniswapV3FactoryModified} from "../src/uniswap_modifications/modified_uniswap_casing/v3-core-modified/IUniswapV3FactoryModified.sol";
import {IUniswapV3PoolAuctionedFirstSwap} from "../src/uniswap_modifications/IUniswapV3PoolAuctionedFirstSwap.sol";
import {INonfungiblePositionManagerModified} from "../src/uniswap_modifications/modified_uniswap_casing/v3-periphery-modified/INonfungiblePositionManagerModified.sol";
import {ISwapRouterModified} from "../src/uniswap_modifications/modified_uniswap_casing/v3-periphery-modified/ISwapRouterModified.sol";
import {ERC20Mintable} from "../src/utils/ERC20Mintable.sol";

import {TickMath} from "v3-core/libraries/TickMath.sol";
import {CCRForgeUtil} from "./utils/CCRForgeUtil.sol";

/**
 * @title Interactions for Poke<>PokeRelayer Contracts
 * @author lilyjjo
 * @dev Commands for interacting with Poked and PokeRelayer on Suave/Goerli
 * @dev Need to fill out environment variables in .env
 * @dev Can toggle between Rigil and local devnet with USE_RIGIL env var
 */
contract Interactions is Script {
    CCRForgeUtil ccrUtil;
    address addressUserGoerli;
    uint256 privateKeyUserGoerli;
    address addressUserGoerli2;
    uint256 privateKeyUserGoerli2;
    address addressUserGoerli3;
    uint256 privateKeyUserGoerli3;

    address addressUserSuave;
    uint256 privateKeyUserSuave;

    address addressStoredSuapp;
    uint256 privateKeyStoredSuapp;

    address addressPoking;
    uint256 privateKeyPoking;

    address addressKettle;

    uint gasNeededGoerliPoke;

    uint chainIdGoerli;
    uint chainIdSuave;
    string rpcUrlGoerli;
    string rpcUrlSuave;
    uint forkIdSuave;
    uint forkIdGoerli;

    address constant SUAPP_AMM_DEPLOYED =
        0x492F9fcC8358D22e372648FCE1328fbBfdAB7399;
    address constant AUCTION_DEPOSITS =
        0x249d1Af8569a692Bc036ef0eF25D898b16CaC728;
    IAuctionGuard constant AUCTION_GUARD =
        IAuctionGuard(0x39De2a59aD3B687Ce7405DE78Fb38604C552003d);

    // Uniswap Pool vars
    uint16 constant POOL_FEE = 3000;
    address constant POOL_DEPLOYED = 0x0F827de6C368EE9043eBaD1640aE8D0c1DaF16E5;
    address constant NPM_DEPLOYED = 0xCE68109c86Fd3C989B06a9A74eB2215A5Be9Ff86;
    address constant ROUTER_DEPLOYED =
        0x6f4107Ff7428a3d5862CF4fA27c6789C992b5288;
    address constant FACTORY_DEPLOYED =
        0xdFDdf8E5AC88Fe0E17d36a52f3B7bC9d9d2138F5;
    address constant TOKEN_0_DEPLOYED =
        0x0A2BF76E18F5c301665CF90199848Fc9fD9aFC6f;
    address constant TOKEN_1_DEPLOYED =
        0x47dfDbaF733bB71932F5EEB6301e9B1CCB5c9F62;

    /**
     * @notice Deploys the PokeRelayer contract on Suave.
     * @dev note: Put this deployed address at the top of the file
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "deploySuaveAMMAuction()" --broadcast --legacy -vv
     */
    function deploySuaveAMMAuction() public {
        vm.selectFork(forkIdSuave);
        vm.startBroadcast(privateKeyUserSuave);

        AMMAuctionSuapp ammAuctionSuapp = new AMMAuctionSuapp(
            POOL_DEPLOYED,
            AUCTION_DEPOSITS,
            chainIdGoerli,
            gasNeededGoerliPoke
        );
        console2.log("ammAuctionSuapp addresss: ");
        console2.log(address(ammAuctionSuapp));
    }

    /**
     * @notice Sets the signing key for the PokedRelayer, expected to be the same key
     * that was used with setPokeExpectedSuaveKey()
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "setSigningKey()" -vv
     */
    function setSigningKey() public {
        // grab most recent singing key with an ethcall
        // note: this can get messed up if there are pending pokes with the key
        vm.selectFork(forkIdGoerli);
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
     * @notice Sets the RPC URL in PokedRelayer used to send transaction to
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "setGoerliUrl()" -vv
     */
    function setGoerliUrl() public {
        vm.selectFork(forkIdSuave);
        bytes memory confidentialInputs = abi.encodePacked(rpcUrlGoerli);
        bytes memory targetCall = abi.encodeWithSignature("setGoerliUrl()");
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
     * @notice Sets the RPC URL in PokedRelayer used to send transaction to
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
     * @dev command: forge script script/Interactions.s.sol:Interactions -vv --sig "newPendingTxn(bool)" true
     */
    function newPendingTxn(bool token0) public {
        bytes memory signedTxn = _createSwapTranscation(
            addressUserGoerli3,
            privateKeyUserGoerli3,
            token0 ? TOKEN_0_DEPLOYED : TOKEN_1_DEPLOYED,
            .1 ether,
            0
        );

        bytes memory targetCall = abi.encodeWithSignature("newPendingTxn()");
        vm.selectFork(forkIdSuave);
        uint64 nonce = vm.getNonce(addressUserSuave);
        ccrUtil.createAndSendCCR({
            signingPrivateKey: privateKeyUserSuave,
            confidentialInputs: signedTxn,
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

    function _createSwapTranscation(
        address swapper,
        uint256 swapperPrivateKey,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut
    ) internal returns (bytes memory) {
        // create txn to be signed
        bytes memory targetCall;
        {
            // scoping for stack too deep errors
            ERC20Mintable tokenOut = ERC20Mintable(
                tokenIn == TOKEN_0_DEPLOYED
                    ? TOKEN_1_DEPLOYED
                    : TOKEN_0_DEPLOYED
            );

            ISwapRouterModified.ExactInputSingleParams memory swapParams;
            swapParams = ISwapRouterModified.ExactInputSingleParams({
                tokenIn: address(tokenIn),
                tokenOut: address(tokenOut),
                fee: POOL_FEE,
                recipient: swapper,
                deadline: block.timestamp + 10000,
                amountIn: amountIn,
                amountOutMinimum: amountOut,
                sqrtPriceLimitX96: 0
            });
            targetCall = abi.encodeWithSelector(
                ISwapRouterModified.exactInputSingle.selector,
                swapParams
            );
        }

        vm.selectFork(forkIdGoerli);
        uint64 nonce = vm.getNonce(swapper); // todo if the minting messes up this nonce

        return
            _signTransaction({
                to: ROUTER_DEPLOYED,
                gas: 100000,
                gasPrice: 100,
                value: 0,
                nonce: nonce,
                targetCall: targetCall,
                chainId: chainIdGoerli,
                privateKey: swapperPrivateKey
            });
    }

    function _signTransaction(
        address to,
        uint256 gas,
        uint256 gasPrice,
        uint256 value,
        uint256 nonce,
        bytes memory targetCall,
        uint256 chainId,
        uint256 privateKey
    ) internal pure returns (bytes memory) {
        // create transaction
        uint8 v;
        bytes32 r;
        bytes32 s;
        {
            // scoping for stack too deep
            Transactions.EIP155Request memory txn = Transactions.EIP155Request({
                to: to,
                gas: gas,
                gasPrice: gasPrice,
                value: value,
                nonce: nonce,
                data: targetCall,
                chainId: chainId
            });

            // TODO: this might be wrong somehow
            // encode transaction
            bytes memory rlpTxn = Transactions.encodeRLP(txn);
            bytes32 digest = keccak256(rlpTxn);
            (v, r, s) = vm.sign(privateKey, digest);
        }

        // encode signed transaction
        Transactions.EIP155 memory signedTxn = Transactions.EIP155({
            to: to,
            gas: gas,
            gasPrice: gasPrice,
            value: value,
            nonce: nonce,
            data: targetCall,
            chainId: chainId,
            v: v,
            r: r,
            s: s
        });

        return Transactions.encodeRLP(signedTxn);
    }

    /**
     * @notice
     * @dev command: forge script script/Interactions.s.sol:Interactions -vv --sig "newBid()"
     */
    function newBid() public {
        // gather bid's values
        address bidder = addressUserGoerli2;
        uint256 bidderPk = privateKeyUserGoerli2;

        vm.selectFork(forkIdGoerli);
        uint256 blockNumber = block.number + 1;
        uint256 bidAmount = 55;

        console2.log("block number: %d", blockNumber);

        (uint8 v, bytes32 r, bytes32 s) = _createWithdrawEIP712(
            bidder,
            bidderPk,
            blockNumber,
            bidAmount
        );
        bytes memory swapTxn = _createSwapTranscation(
            bidder,
            bidderPk,
            TOKEN_0_DEPLOYED,
            .01 ether,
            0
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
     * @notice Helper function for signing pokes.
     */
    function _createWithdrawEIP712(
        address user,
        uint256 userPk,
        uint256 blockNumber,
        uint256 payment
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        // setup SigUtils
        bytes32 TYPEHASH = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

        bytes32 WITHDRAW_TYPEHASH = keccak256(
            "withdrawBid(address bidder,uint256 blockNumber,uint256 amount)"
        );

        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                TYPEHASH,
                keccak256(bytes("AuctionDeposits")),
                keccak256(bytes("v1")),
                5,
                SUAPP_AMM_DEPLOYED
            )
        );
        SigUtils sigUtils = new SigUtils(DOMAIN_SEPARATOR, WITHDRAW_TYPEHASH);
        bytes32 digest = sigUtils.getTypedDataHash(user, blockNumber, payment);
        (v, r, s) = vm.sign(userPk, digest);
    }

    /**
     * @notice Sets the RPC URL in PokedRelayer used to send transaction to
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "testBlockCode()" -vv
     */
    function testBlockCode() public {
        vm.selectFork(forkIdSuave);
        bytes memory confidentialInputs = abi.encodePacked("");
        bytes memory targetCall = abi.encodeWithSignature(
            "getLastL1Block(string)",
            rpcUrlGoerli
        );
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
     * @notice Helper function to give funds and approve a third
     * party to spend those funds.
     */
    function _fundAndApprove(
        address user,
        uint256 userPrivateKey,
        address approved,
        ERC20Mintable token,
        uint256 amount
    ) internal {
        vm.startBroadcast(privateKeyUserGoerli);
        token.mint(user, amount);
        vm.stopBroadcast();
        vm.startBroadcast(userPrivateKey);
        token.approve(approved, type(uint256).max);
        vm.stopBroadcast();
    }

    /**
     * @notice Adds liquidity.
     */
    function _addLiquidity(
        address liquidityProvider,
        uint256 liquidtyProviderPrivateKey,
        uint256 token0Amount,
        uint256 token1Amount,
        bool mintTokens
    ) internal returns (uint256, uint256) {
        if (mintTokens) {
            // mint liquidity provider tokens
            _fundAndApprove(
                liquidityProvider,
                liquidtyProviderPrivateKey,
                address(NPM_DEPLOYED),
                ERC20Mintable(TOKEN_0_DEPLOYED),
                token0Amount
            );
            _fundAndApprove(
                liquidityProvider,
                liquidtyProviderPrivateKey,
                address(NPM_DEPLOYED),
                ERC20Mintable(TOKEN_1_DEPLOYED),
                token1Amount
            );
        }

        vm.startBroadcast(liquidtyProviderPrivateKey);

        // supply liquidty across whole range, adjusted for tick spacing needs
        int24 tickSpacing = IUniswapV3PoolAuctionedFirstSwap(POOL_DEPLOYED)
            .tickSpacing();
        int24 tickLower = -887272;
        int24 tickUpper = -tickLower;
        tickLower = tickLower < 0
            ? -((-tickLower / tickSpacing) * tickSpacing)
            : (tickLower / tickSpacing) * tickSpacing;
        tickUpper = tickUpper < 0
            ? -((-tickUpper / tickSpacing) * tickSpacing)
            : (tickUpper / tickSpacing) * tickSpacing;

        INonfungiblePositionManagerModified.MintParams
            memory mintParams = INonfungiblePositionManagerModified.MintParams({
                token0: address(TOKEN_0_DEPLOYED),
                token1: address(TOKEN_1_DEPLOYED),
                fee: POOL_FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: token0Amount,
                amount1Desired: token1Amount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: liquidityProvider,
                deadline: 1740161987,
                pool: address(POOL_DEPLOYED)
            });

        (
            ,
            /*uint256 tokenId*/
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = INonfungiblePositionManagerModified(NPM_DEPLOYED).mint(mintParams);

        console2.log("Liquidity added: %d", liquidity);
        console2.log("amount0: %d", amount0);
        console2.log("amount1: %d", amount1);

        return (amount0, amount1);
    }

    /**
     * @notice Deploys the L1 contracts
     * @dev note: Put these deployed contracts at the top of the file
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "deployL1Contracts()" --broadcast --legacy -vv --verify
     */
    function deployL1Contracts() public {
        vm.selectFork(forkIdGoerli);
        vm.startBroadcast(privateKeyUserGoerli);

        // (1) Auction Deposits
        IAuctionDeposits auctionDeposits = new AuctionDeposits();
        console2.log("auctionDeposits: ");
        console2.log(address(auctionDeposits));

        // (2) Auction Guard
        IAuctionGuard auctionGuard = new AuctionGuard(
            address(auctionDeposits),
            addressStoredSuapp
        );
        auctionDeposits.setAuction(address(auctionGuard));
        console2.log("auctionGuard: ");
        console2.log(address(auctionGuard));

        // initialize token0/token1/WETH
        ERC20Mintable token0;
        ERC20Mintable token1;

        address tokenA = address(new ERC20Mintable("A", "A"));
        address tokenB = address(new ERC20Mintable("B", "B"));
        if (tokenA < tokenB) {
            token0 = ERC20Mintable(tokenA);
            token1 = ERC20Mintable(tokenB);
        } else {
            token0 = ERC20Mintable(tokenB);
            token1 = ERC20Mintable(tokenA);
        }
        ERC20Mintable WETH = new ERC20Mintable("WETH", "WETH");

        console2.log("token0: ");
        console2.log(address(token0));
        console2.log("token1: ");
        console2.log(address(token1));
        console2.log("WETH: ");
        console2.log(address(WETH));

        // initialize Factory
        IUniswapV3FactoryModified uniswapV3Factory = IUniswapV3FactoryModified(
            deployCode("UniswapV3FactoryModified.sol")
        );

        console2.log("uniswapV3Factory: ");
        console2.log(address(uniswapV3Factory));

        // initialize Pool
        IUniswapV3PoolAuctionedFirstSwap pool = IUniswapV3PoolAuctionedFirstSwap(
                uniswapV3Factory.createPool(
                    address(token0),
                    address(token1),
                    POOL_FEE,
                    address(auctionGuard)
                )
            );

        console2.log("pool: ");
        console2.log(address(pool));

        int24 tickSpacing = pool.tickSpacing();
        int24 targetStartTick = 0;
        targetStartTick = targetStartTick < 0
            ? -((-targetStartTick / tickSpacing) * tickSpacing)
            : (targetStartTick / tickSpacing) * tickSpacing;

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(targetStartTick);
        pool.initialize(sqrtPriceX96);

        // grow available observations in pool
        pool.increaseObservationCardinalityNext(10);

        // initialize PositionManager
        INonfungiblePositionManagerModified positionManager = INonfungiblePositionManagerModified(
                deployCode(
                    "NonfungiblePositionManagerModified.sol",
                    abi.encode(
                        address(uniswapV3Factory),
                        address(WETH),
                        "Test token descriptor",
                        address(pool)
                    )
                )
            );

        console2.log("positionManager: ");
        console2.log(address(positionManager));

        // initialize swapRouter
        ISwapRouterModified swapRouter = ISwapRouterModified(
            deployCode(
                "SwapRouterModified.sol",
                abi.encode(
                    address(uniswapV3Factory),
                    address(WETH),
                    address(pool)
                )
            )
        );

        console2.log("swapRouter: ");
        console2.log(address(swapRouter));

        vm.stopBroadcast();
    }

    /**
     * @notice adds liquidity to contracts
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "addLiquidity()" --broadcast --legacy -vv --verify
     */
    function addLiquidity() public {
        vm.selectFork(forkIdGoerli);
        _addLiquidity(
            addressUserGoerli2,
            privateKeyUserGoerli2,
            10 ether,
            10 ether,
            false
        );
    }

    /**
     * @notice
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "enableAuctions()" --broadcast --legacy -vv
     */
    function enableAuctions() public {
        vm.selectFork(forkIdGoerli);
        vm.startBroadcast(privateKeyUserGoerli);
        AUCTION_GUARD.enableAuction(true);
    }

    /**
     * @notice Pulls environment variables and sets up fork urls.
     * @dev Toggle between Rigil and local devnet with 'USE_RIGIL'
     */
    function setUp() public {
        // setup goerli variables
        chainIdGoerli = vm.envUint("CHAIN_ID_GOERLI");
        rpcUrlGoerli = vm.envString("RPC_URL_GOERLI");
        addressUserGoerli = vm.envAddress("FUNDED_ADDRESS_GOERLI");
        privateKeyUserGoerli = uint256(
            vm.envBytes32("FUNDED_PRIVATE_KEY_GOERLI")
        );

        addressUserGoerli2 = vm.envAddress("FUNDED_ADDRESS_GOERLI_I");
        privateKeyUserGoerli2 = uint256(
            vm.envBytes32("FUNDED_PRIVATE_KEY_GOERLI_I")
        );

        addressUserGoerli3 = vm.envAddress("FUNDED_ADDRESS_GOERLI_II");
        privateKeyUserGoerli3 = uint256(
            vm.envBytes32("FUNDED_PRIVATE_KEY_GOERLI_II")
        );

        // Poking related values
        addressPoking = vm.envAddress("ADDRESS_SIGNING_POKE");
        privateKeyPoking = uint256(vm.envBytes32("PRIVATE_KEY_SIGNING_POKE"));
        gasNeededGoerliPoke = vm.envUint("GAS_NEEDED_GOERLI_POKE");

        // private key to store in suapp
        addressStoredSuapp = vm.envAddress(
            "FUNDED_GOERLI_ADDRESS_TO_PUT_INTO_SUAPP"
        );
        privateKeyStoredSuapp = uint256(
            vm.envBytes32("FUNDED_GOERLI_PRIVATE_KEY_TO_PUT_INTO_SUAPP")
        );

        // setup suave variable, toggle between using local devnet and rigil testnet
        if (vm.envBool("USE_RIGIL")) {
            // grab rigil variables
            chainIdSuave = vm.envUint("CHAIN_ID_RIGIL");
            rpcUrlSuave = vm.envString("RPC_URL_RIGIL");
            addressUserSuave = vm.envAddress("FUNDED_ADDRESS_RIGIL");
            privateKeyUserSuave = uint256(
                vm.envBytes32("FUNDED_PRIVATE_KEY_RIGIL")
            );
            addressKettle = vm.envAddress("KETTLE_ADDRESS_RIGIL");
        } else {
            // grab local variables
            chainIdSuave = vm.envUint("CHAIN_ID_LOCAL_SUAVE");
            rpcUrlSuave = vm.envString("RPC_URL_LOCAL_SUAVE");
            addressUserSuave = vm.envAddress("FUNDED_ADDRESS_SUAVE_LOCAL");
            privateKeyUserSuave = uint256(
                vm.envBytes32("FUNDED_PRIVATE_KEY_SUAVE_LOCAL")
            );
            addressKettle = vm.envAddress("KETTLE_ADDRESS_SUAVE_LOCAL");
        }

        // create forkURLs to toggle between chains
        forkIdSuave = vm.createFork(rpcUrlSuave);
        forkIdGoerli = vm.createFork(rpcUrlGoerli);

        // setup confidential compute request util for use on suave fork (note is local)
        vm.selectFork(forkIdSuave);
        ccrUtil = new CCRForgeUtil();
    }
}
