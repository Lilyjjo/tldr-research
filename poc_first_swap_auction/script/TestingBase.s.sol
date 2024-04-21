// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {CCRForgeUtil} from "./utils/CCRForgeUtil.sol";

contract TestingBase is Script {
    CCRForgeUtil ccrUtil;
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
        0x6ED804B9d4FAAE9e092Fe6d73292151FCF5F0413;
    address constant AUCTION_GUARD = 0x8948F78709Bf2F9837678ec4eE358338Efc1DdAf;

    // Uniswap Pool vars
    uint16 constant POOL_FEE = 3000;
    address constant POOL_DEPLOYED = 0xB61248c43ec21f2BaD0739f0ae32a4A1BeCB3a71;
    address constant NPM_DEPLOYED = 0x016d4c87eF982e341E633F3467579E20FF38E089;
    address constant ROUTER_DEPLOYED =
        0x48C5D0e3bde6E4e2E174Aa9216D2aF496c9A0B21;
    address constant FACTORY_DEPLOYED =
        0x862DE3391fD6cE8ab668DD316bc3d9655Eda68E5;
    address constant TOKEN_0_DEPLOYED =
        0x298134EC54C3E7Ba9a4b3D0b4E06152391CF1e77;
    address constant TOKEN_1_DEPLOYED =
        0xE4b04dC57F7CCe5f57F8c0151c2c914fdeF487a7;

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

        // setup confidential compute request util for use on suave fork (note is local)
        vm.selectFork(forkIdSuave);
        ccrUtil = new CCRForgeUtil();
    }
}
