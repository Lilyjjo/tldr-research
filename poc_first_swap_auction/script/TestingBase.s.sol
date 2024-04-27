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

    // Needed vars for deploying AuctionAMM
    address constant AUCTION_DEPOSITS =
        0x08428691D343Aa2EF699b0BCef8dB809D9085ebD;
    address constant AUCTION_GUARD = 0x46e42509A8c3127d466f26EBf6A9646D89DEaB39;
    address constant POOL_DEPLOYED = 0x5DC6F55f1B524Ae19006b92d77678f89050bD98F;
    address constant ROUTER_DEPLOYED =
        0x862DE3391fD6cE8ab668DD316bc3d9655Eda68E5;

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
