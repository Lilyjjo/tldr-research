// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {PokeRelayer} from "../src/PokeRelayer.sol";
import {GoerliChainInfo} from "../src/GoerliChainInfo.sol";
import {Poked} from "../src/Poked.sol";
import {SigUtils} from "./utils/EIP712Helpers.sol";

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
    --rpc-url goerli \
    --sig "setSuappPkOnGoerli()" \
    --broadcast \
    --legacy \
    -vv
     */
    function setSuappPkOnGoerli() public {
        vm.startBroadcast(goerliPrivateKey);
        Poked poked = Poked(vm.envAddress("DEPLOYED_GOERLI_POKED"));
        poked.setSuapp(vm.envAddress("FUNDED_ADDRESS_TO_PUT_INTO_SUAPP"));
        vm.stopBroadcast();
    }

    /**
    forge script script/Interactions.s.sol:Interactions \
    --rpc-url rigil \
    --sig "deploySuavePokeRelayer()" \
    --broadcast --legacy -vv 
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
        console2.logString(chainIdStringGoerli);
        vm.stopBroadcast();
    }

    /**
    forge script \
    script/Interactions.s.sol:Interactions \
    --rpc-url rigil \
    --sig "testPrivateKeyStore()" \
    -vv
     */
    function testPrivateKeyStore() public {
        // setup data for confidential compute request
        address suapp = vm.envAddress("DEPLOYED_SUAVE_SUAPP");

        bytes memory targetCall = abi.encodeWithSignature(
            "testPrivateKeyStore()"
        );
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
    --sig "setSigningKey(uint256)" 10 \
    --rpc-url rigil \
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
        uint256 keyNonce = uint256(vm.load(suaveSigner, bytes32(uint(7))));
        uint256 ethCallCounter = uint256(
            vm.load(suaveSigner, bytes32(uint(8)))
        );
        uint256 blockNumber = uint256(vm.load(suaveSigner, bytes32(uint(9))));
        uint256 blockBaseFee = uint256(vm.load(suaveSigner, bytes32(uint(10))));
        console2.log("ethCallCounter: %d", ethCallCounter);
        console2.log("blockNumber: %d", blockNumber);
        console2.log("blockBaseFee: %d", blockBaseFee);
        console2.log("keyNonce: %d", keyNonce);
    }

    /** 
        forge script \
        script/Interactions.s.sol:Interactions \
        --rpc-url rigil \
        --sig "grabValueSigningKey()" \
        -vv 
     */
    function grabValueSigningKey() public {
        address suaveSigner = vm.envAddress("DEPLOYED_SUAVE_SUAPP");
        bytes32 storedPk = bytes32(vm.load(suaveSigner, bytes32(uint(11))));
        console2.logBytes32(storedPk);
    }

    /**
    forge script script/Interactions.s.sol:Interactions --rpc-url rigil \
    --sig "sendPokeToSuave()" -vv  
     */
    function sendPokeToSuave() public {
        // setup SigUtils
        bytes32 POKE_TYPEHASH = 0x55520b7dd6f5df16c1f127cbc597b5edac9c3b9ddd62140e3daa73d59795080c;

        Poked poked = Poked(vm.envAddress("DEPLOYED_GOERLI_POKED"));
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                POKE_TYPEHASH,
                keccak256(bytes("SuappCounter")),
                keccak256(bytes("1")),
                5,
                address(poked)
            )
        );

        SigUtils sigUtils = new SigUtils(DOMAIN_SEPARATOR);

        // make signed message from any private/public keyapir
        address user = vm.envAddress("FUNDED_ADDRESS_SUAVE_LOCAL");
        uint256 userPk = uint256(
            vm.envBytes32("FUNDED_PRIVATE_KEY_SUAVE_LOCAL")
        );
        address suappSigningKey = vm.envAddress(
            "FUNDED_ADDRESS_TO_PUT_INTO_SUAPP"
        );
        uint deadline = (vm.unixTime() / 1e3) + uint(200);
        console2.log(deadline);
        uint pokeNonce = 1; // will need to actually grab value, can't use vm.getNonce this is a contract specific value

        SigUtils.Poke memory poke = SigUtils.Poke({
            user: user,
            permittedSuapp: suappSigningKey,
            deadline: deadline,
            nonce: pokeNonce
        });

        bytes32 digest = sigUtils.getTypedDataHash(poke);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

        bytes memory confidentialInputs = abi.encode("");
        bytes memory targetCall = abi.encodeWithSignature(
            "newPokeBid(address,address,uint256,uint8,bytes32,bytes32)",
            user,
            suappSigningKey,
            deadline,
            v,
            r,
            s
        );
        uint64 nonce = vm.getNonce(suaveUserAddress);
        address suapp = vm.envAddress("DEPLOYED_SUAVE_SUAPP");

        ccrUtil.createAndSendCCR({
            signingPrivateKey: suaveUserPrivateKey,
            confidentialInputs: confidentialInputs,
            targetCall: targetCall,
            nonce: nonce,
            to: suapp,
            gas: 10000000,
            gasPrice: 1000000000,
            value: 0,
            executionNode: address(kettleAddress),
            chainId: uint256(0x01008C45)
        });
    }
}
