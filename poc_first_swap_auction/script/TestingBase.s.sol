// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";

contract TestingBase is Script {
    address public suave_signer;
    uint256 public suave_signer_pk;
    address public suapp_signer;
    uint256 public suapp_signer_pk;

    address public bidder_0;
    uint256 public bidder_0_pk;
    address public bidder_1;
    uint256 public bidder_1_pk;
    address public bidder_2;
    uint256 public bidder_2_pk;
    address public swapper_0;
    uint256 public swapper_0_pk;
    address public swapper_1;
    uint256 public swapper_1_pk;
    address public swapper_2;
    uint256 public swapper_2_pk;

    address public execution_node;
    uint public gasNeeded;

    uint public chainIdL1;
    uint public chainIdSuave;
    string public rpcUrlL1;
    string public rpcUrlSuave;
    uint public forkIdL1;
    uint public forkIdSuave;

    address public suapp_amm;
    address public auction_deposits;
    address public auction_guard;
    address public swap_router;
    address public pool;
    address public token_0;
    address public token_1;

    // Uniswap Pool vars
    uint16 public constant POOL_FEE = 3000;

    /**
     * @notice Pulls environment variables and sets up fork urls.
     * @dev Toggle between Rigil and local devnet with 'USE_LOCAL'
     */
    function TestingBaseSetUp() public {
        // setup common variables
        chainIdL1 = vm.envUint("CHAIN_ID_L1");
        chainIdSuave = vm.envUint("CHAIN_ID_SUAVE");
        rpcUrlL1 = vm.envString("RPC_URL_L1");

        suapp_signer = vm.envAddress("SUAPP_SIGNER");
        suapp_signer_pk = uint256(vm.envBytes32("SUAPP_SIGNER_PK"));

        bidder_0 = vm.envAddress("BIDDER_0");
        bidder_0_pk = uint256(vm.envBytes32("BIDDER_0_PK"));
        bidder_1 = vm.envAddress("BIDDER_1");
        bidder_1_pk = uint256(vm.envBytes32("BIDDER_1_PK"));
        bidder_2 = vm.envAddress("BIDDER_2");
        bidder_2_pk = uint256(vm.envBytes32("BIDDER_2_PK"));

        swapper_0 = vm.envAddress("SWAPPER_0");
        swapper_0_pk = uint256(vm.envBytes32("SWAPPER_0_PK"));
        swapper_1 = vm.envAddress("SWAPPER_1");
        swapper_1_pk = uint256(vm.envBytes32("SWAPPER_1_PK"));
        swapper_2 = vm.envAddress("SWAPPER_2");
        swapper_2_pk = uint256(vm.envBytes32("SWAPPER_2_PK"));

        // setup local/rigil specific variables, toggle between using local devnet and rigil testnet
        if (vm.envBool("USE_LOCAL")) {
            // grab rigil variables
            rpcUrlSuave = vm.envString("RPC_URL_SUAVE_LOCAL");
            suave_signer = vm.envAddress("SUAVE_SIGNER_LOCAL");
            suave_signer_pk = uint256(vm.envBytes32("SUAVE_SIGNER_LOCAL_PK"));
            execution_node = vm.envAddress("EXECUTION_NODE_SUAVE_LOCAL");
        } else {
            // grab local variables
            rpcUrlSuave = vm.envString("RPC_URL_SUAVE");
            suave_signer = vm.envAddress("SUAVE_SIGNER");
            suave_signer_pk = uint256(vm.envBytes32("SUAVE_SIGNER_PK"));
            execution_node = vm.envAddress("EXECUTION_NODE_SUAVE");
        }

        // create forkURLs to toggle between chains
        forkIdSuave = vm.createFork(rpcUrlSuave);
        forkIdL1 = vm.createFork(rpcUrlL1);
    }
}
