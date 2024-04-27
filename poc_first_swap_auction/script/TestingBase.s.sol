// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";

contract TestingBase is Script {
    address addressUserSepolia;
    uint256 privateKeyUserSepolia;
    address addressUserSepolia2;
    uint256 privateKeyUserSepolia2;
    address addressUserSepolia3;
    uint256 privateKeyUserSepolia3;

    address addressUserSuave;
    uint256 privateKeyUserSuave;

    address addressStoredSuapp;
    uint256 privateKeyStoredSuapp;

    address addressPoking;
    uint256 privateKeyPoking;

    address addressKettle;

    uint gasNeededSepoliaPoke;

    uint chainIdSepolia;
    uint chainIdSuave;
    string rpcUrlSepolia;
    string rpcUrlSuave;
    uint forkIdSuave;
    uint forkIdSepolia;

    /*

    == Logs ==
  auctionDeposits:
  0x84d3c27172dF56151a49925391E96eBF6Eb5EA2C
  auctionGuard:
  0x34f2a29C5F685c920183d3819384CFC7D714E585
  token0:
  0x5b554bAAdefd2CE9E65322185d387a2a386E801F
  token1:
  0x7CDd4e7Aa349b5d13189ef3D162eb2EDA25F126C
  WETH:
  0x5941218c1D4FA0f25611D6c71Fe3bd966f6bbE2b
  uniswapV3Factory:
  0xe54D3F8C9140EbA09d6f76f36ECf2D10C50b5207
  pool:
  0x3Fe62E0E77014E0D7A53C700d9309DBCE5408129
  positionManager:
  0x2A132cF9081Ea3ca191A13CA5E5d208f428601DE
  swapRouter:
  0x6364d403fAe57403f924548849a2a40187a27709
  Liquidity added: 10000000000000000000
  amount0: 10000000000000000000
  amount1: 10000000000000000000

*/

    address constant SUAPP_AMM_DEPLOYED =
        0xa878e40976A59521EFcC7F1b644D0dc79b7A54C3;
    address constant AUCTION_DEPOSITS =
        0x08428691D343Aa2EF699b0BCef8dB809D9085ebD;
    address constant AUCTION_GUARD = 0x46e42509A8c3127d466f26EBf6A9646D89DEaB39;

    // Uniswap Pool vars
    uint16 constant POOL_FEE = 3000;
    address constant POOL_DEPLOYED = 0x5DC6F55f1B524Ae19006b92d77678f89050bD98F;
    address constant NPM_DEPLOYED = 0x9ac7e50F478464d5e65B69b7FD7e1895Ddd485a6;
    address constant ROUTER_DEPLOYED =
        0x862DE3391fD6cE8ab668DD316bc3d9655Eda68E5;
    address constant FACTORY_DEPLOYED =
        0x8948F78709Bf2F9837678ec4eE358338Efc1DdAf;
    address constant TOKEN_0_DEPLOYED =
        0x82C5A0585be25CeB3c8BaA7daadC3c3c77ceBd1b;
    address constant TOKEN_1_DEPLOYED =
        0xB8d1d45Af8ffCF9d553b1B38907149f1Aa153378;

    /**
     * @notice Pulls environment variables and sets up fork urls.
     * @dev Toggle between Rigil and local devnet with 'USE_RIGIL'
     */
    function TestingBaseSetUp() public {
        // setup sepolia variables
        chainIdSepolia = vm.envUint("CHAIN_ID_SEPOLIA");
        rpcUrlSepolia = vm.envString("RPC_URL_SEPOLIA");
        addressUserSepolia = vm.envAddress("FUNDED_ADDRESS_SEPOLIA");
        privateKeyUserSepolia = uint256(
            vm.envBytes32("FUNDED_PRIVATE_KEY_SEPOLIA")
        );

        addressUserSepolia2 = vm.envAddress("FUNDED_ADDRESS_SEPOLIA_I");
        privateKeyUserSepolia2 = uint256(
            vm.envBytes32("FUNDED_PRIVATE_KEY_SEPOLIA_I")
        );

        addressUserSepolia3 = vm.envAddress("FUNDED_ADDRESS_SEPOLIA_II");
        privateKeyUserSepolia3 = uint256(
            vm.envBytes32("FUNDED_PRIVATE_KEY_SEPOLIA_II")
        );

        // Poking related values
        addressPoking = vm.envAddress("ADDRESS_SIGNING_POKE");
        privateKeyPoking = uint256(vm.envBytes32("PRIVATE_KEY_SIGNING_POKE"));
        gasNeededSepoliaPoke = vm.envUint("GAS_NEEDED_SEPOLIA_POKE");

        // private key to store in suapp
        addressStoredSuapp = vm.envAddress(
            "FUNDED_SEPOLIA_ADDRESS_TO_PUT_INTO_SUAPP"
        );
        privateKeyStoredSuapp = uint256(
            vm.envBytes32("FUNDED_SEPOLIA_PRIVATE_KEY_TO_PUT_INTO_SUAPP")
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
        forkIdSepolia = vm.createFork(rpcUrlSepolia);
    }
}
