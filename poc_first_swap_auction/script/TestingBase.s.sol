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

    address constant SUAPP_AMM_DEPLOYED =
        0x7481C68EC1BE6b2d29d26532d4f205C99C5AE031;
    address constant AUCTION_DEPOSITS =
        0x055FcE5d6BC15EcEf4B4976195A3233A2C60e6F3;
    address constant AUCTION_GUARD = 0x2f35d2d2499a77aF1c60B5A9D6F5ad55D9879ba0;

    // Uniswap Pool vars
    uint16 constant POOL_FEE = 3000;
    address constant POOL_DEPLOYED = 0x0A033A33A37A6fA34C0EA8bE106331c3037f8790;
    address constant NPM_DEPLOYED = 0xF67803Df1f56957fF60488620Ff1BB6F67085C6c;
    address constant ROUTER_DEPLOYED =
        0x8500aD83e21C9C641fE78aaa4B848F04329E287e;
    address constant FACTORY_DEPLOYED =
        0x22D42bc9e98933784B1f033aed4C4dbbf161dAA7;
    address constant TOKEN_0_DEPLOYED =
        0x054576E378fCCD8F8331dC055c772EB775E61DF3;
    address constant TOKEN_1_DEPLOYED =
        0x45E4CF4844160A9B6FB931a184E7bAE8A1AC9A49;

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
