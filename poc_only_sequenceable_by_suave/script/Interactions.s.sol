// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {PokeRelayer} from "../src/PokeRelayer.sol";
import {GoerliChainInfo} from "../src/GoerliChainInfo.sol";
import {Poked} from "../src/Poked.sol";

import {CCRForgeUtil} from "./utils/CCRForgeUtil.sol";

contract Interactions is Script {
    CCRForgeUtil ccrUtil;
    address suaveUserAddress;
    uint256 suaveUserPrivateKey;

    address goerliUserAddress;
    uint256 goerliPrivateKey;

    address kettleAddress;

    address suappStoredAddress;
    uint256 suappStoredPrivateKey;

    address pokedGoerli;
    address chainInfoGoerli;

    uint gasNeeded;
    uint startingKeyNonce;
    uint chainIdSuave;
    string chainIdStringSuave;
    uint chainIdGoerli;
    string chainIdStringGoerli;

    function setUp() public {
        // Set these in the .env
        suaveUserAddress = vm.envAddress("FUNDED_ADDRESS_RIGIL");
        suaveUserPrivateKey = uint256(
            vm.envBytes32("FUNDED_PRIVATE_KEY_RIGIL")
        );
        kettleAddress = vm.envAddress("KETTLE_ADDRESS_RIGIL");
        pokedGoerli = vm.envAddress("DEPLOYED_GOERLI_POKED");
        chainInfoGoerli = vm.envAddress("DEPLOYED_GOERLI_CHAIN_INFO");
        chainIdGoerli = vm.envUint("CHAIN_ID_GOERLI");
        chainIdStringGoerli = vm.envString("CHAIN_ID_STRING_GOERLI");
        suappStoredAddress = vm.envAddress("FUNDED_ADDRESS_TO_PUT_INTO_SUAPP");
        suappStoredPrivateKey = uint256(
            vm.envBytes32("FUNDED_PRIVATE_KEY_TO_PUT_INTO_SUAPP")
        );
        goerliPrivateKey = uint256(vm.envBytes32("FUNDED_PRIVATE_KEY_GOERLI"));
        gasNeeded = vm.envUint("GAS_NEEDED");
        chainIdSuave = vm.envUint("CHAIN_ID_SUAVE");
        chainIdStringSuave = vm.envString("CHAIN_ID_STRING_SUAVE");
        ccrUtil = new CCRForgeUtil();
    }

    /**
    forge script \
    script/Interactions.s.sol:Interactions \
    --rpc-url goerli \
    --sig "deployGoerliContracts()" \
    --broadcast \
    --legacy \
    -vv
     */
    function deployGoerliContracts() public {
        vm.startBroadcast(goerliPrivateKey);
        Poked poked = new Poked();
        console2.log("poked: ");
        console2.log(address(poked));
        GoerliChainInfo chainInfo = new GoerliChainInfo();
        console2.log("chainInfo: ");
        console2.log(address(chainInfo));
        vm.stopBroadcast();
    }

    /**
    forge script \
    script/Interactions.s.sol:Interactions \
    --rpc-url rigil \
    --sig "deploySuavePokeRelayer()" \
    --broadcast \
    --legacy \
    -vv 
     */
    function deploySuavePokeRelayer() public {
        vm.startBroadcast(suaveUserPrivateKey);
        PokeRelayer pokeRelayer = new PokeRelayer(
            pokedGoerli,
            chainInfoGoerli,
            chainIdGoerli,
            chainIdStringGoerli,
            gasNeeded
        );
        console2.log("addresss: ");
        console2.log(address(pokeRelayer));
        vm.stopBroadcast();
    }

    /**
    forge script \
    script/Interactions.s.sol:Interactions \
    --rpc-url rigil \
    --sig "testEthCall()" 1 \
    -vv
     */
    function testEthCall() public {
        // setup data for confidential compute request
        address suapp = vm.envAddress("DEPLOYED_SUAVE_SUAPP");

        bytes memory targetCall = abi.encodeWithSignature("testEthCall()");
        bytes memory confidentialInputs = abi.encode("");
        uint64 nonce = vm.getNonce(suaveUserAddress);

        ccrUtil.createAndSendCCR({
            signingPrivateKey: suaveUserPrivateKey,
            confidentialInputs: confidentialInputs,
            targetCall: targetCall,
            nonce: nonce,
            to: suapp,
            gas: 1000000,
            gasPrice: 1000000000,
            value: 0,
            executionNode: address(kettleAddress),
            chainId: uint256(0x01008C45)
        });
    }

    /**
    forge script \
    script/Interactions.s.sol:Interactions \
    --rpc-url rigil \
    --sig "setSigningKey(uint256)" 1 \
    -vv  
     */
    function setSigningKey(uint256 signingKeyNonce) public {
        // setup data for confidential compute request
        bytes memory confidentialInputs = abi.encode(suappStoredPrivateKey);
        bytes memory targetCall = abi.encodeWithSignature(
            "setSigningKey(uint256)",
            signingKeyNonce
        );
        uint64 nonce = vm.getNonce(suaveUserAddress);
        address suapp = vm.envAddress("DEPLOYED_SUAVE_SUAPP");

        ccrUtil.createAndSendCCR({
            signingPrivateKey: suaveUserPrivateKey,
            confidentialInputs: confidentialInputs,
            targetCall: targetCall,
            nonce: nonce,
            to: suapp,
            gas: 1000000,
            gasPrice: 1000000000,
            value: 0,
            executionNode: address(kettleAddress),
            chainId: uint256(0x01008C45)
        });
    }

    /** 
        forge script \
        script/Interactions.s.sol:Interactions \
        --rpc-url rigil \
        --sig "grabValueKeyNonce()" \
        -vv 
     */
    function grabValueKeyNonce() public {
        address suaveSigner = vm.envAddress("DEPLOYED_SUAVE_SUAPP");
        uint256 key = uint256(vm.load(suaveSigner, bytes32(uint(7))));
        console2.log("keyNonce: %d", key);
    }

    /** 
        forge script \
        script/Interactions.s.sol:Interactions \
        --rpc-url rigil \
        --sig "grabValueEthCall()" \
        -vv 
     */
    function grabValueEthCall() public {
        address suaveSigner = vm.envAddress("DEPLOYED_SUAVE_SUAPP");
        uint256 ethCallCounter = uint256(
            vm.load(suaveSigner, bytes32(uint(8)))
        );
        uint256 gasValue = uint256(vm.load(suaveSigner, bytes32(uint(9))));
        console2.log("ethCallCounter: %d", ethCallCounter);
        console2.log("key store record id: %d", gasValue);
    }
}
