/ SPDX-License-Identifier: UNLICENSED
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

contract Storage is Script {
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
}
