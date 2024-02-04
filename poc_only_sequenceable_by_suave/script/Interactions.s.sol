// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {PokeRelayer} from "../src/PokeRelayer.sol";
import {Poked} from "../src/Poked.sol";
import {SigUtils} from "./utils/EIP712Helpers.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

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

    address constant POKE_RELAYER_DEPLOYED = 0xe1936a1de5f2f311F1d69254bd22C94F47610A63;
    address constant POKED_DEPLOYED = 0xB8d1d45Af8ffCF9d553b1B38907149f1Aa153378;

    /**
     * @notice Pulls environment variables and sets up fork urls.
     * @dev Toggle between Rigil and local devnet with 'USE_RIGIL'
     */
    function setUp() public {
        // setup goerli variables
        chainIdGoerli = vm.envUint("CHAIN_ID_GOERLI");
        rpcUrlGoerli = vm.envString("RPC_URL_GOERLI");
        addressUserGoerli = vm.envAddress("FUNDED_ADDRESS_GOERLI"); 
        privateKeyUserGoerli = uint256(vm.envBytes32("FUNDED_PRIVATE_KEY_GOERLI"));
         
        // Poking related values
        addressPoking = vm.envAddress("ADDRESS_SIGNING_POKE"); 
        privateKeyPoking = uint256(vm.envBytes32("PRIVATE_KEY_SIGNING_POKE")); 
        gasNeededGoerliPoke = vm.envUint("GAS_NEEDED_GOERLI_POKE");

        // private key to store in suapp
        addressStoredSuapp = vm.envAddress("FUNDED_GOERLI_ADDRESS_TO_PUT_INTO_SUAPP");
        privateKeyStoredSuapp = uint256(vm.envBytes32("FUNDED_GOERLI_PRIVATE_KEY_TO_PUT_INTO_SUAPP")); 

        // setup suave variable, toggle between using local devnet and rigil testnet
        if(vm.envBool("USE_RIGIL")) {
            // grab rigil variables
            chainIdSuave = vm.envUint("CHAIN_ID_RIGIL");
            rpcUrlSuave = vm.envString("RPC_URL_RIGIL");
            addressUserSuave = vm.envAddress("FUNDED_ADDRESS_RIGIL");
            privateKeyUserSuave = uint256(vm.envBytes32("FUNDED_PRIVATE_KEY_RIGIL"));
            addressKettle = vm.envAddress("KETTLE_ADDRESS_RIGIL");
        } else {
            // grab local variables
            chainIdSuave = vm.envUint("CHAIN_ID_LOCAL_SUAVE");
            rpcUrlSuave = vm.envString("RPC_URL_LOCAL_SUAVE");
            addressUserSuave = vm.envAddress("FUNDED_ADDRESS_SUAVE_LOCAL");
            privateKeyUserSuave = uint256(vm.envBytes32("FUNDED_PRIVATE_KEY_SUAVE_LOCAL"));
            addressKettle = vm.envAddress("KETTLE_ADDRESS_SUAVE_LOCAL");

        }
        
        // create forkURLs to toggle between chains 
        forkIdSuave = vm.createFork(rpcUrlSuave);
        forkIdGoerli = vm.createFork(rpcUrlGoerli);

        // setup confidential compute request util for use on suave fork (note is local)
        vm.selectFork(forkIdSuave);
        ccrUtil = new CCRForgeUtil();
    }

    /**
     * @notice Deploys the Poke contract to Goerli.
     * @dev note: Put this deployed address at the top of the file
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "deployPoke()" --broadcast --legacy -vv --verify
     */
    function deployPoke() public {
        vm.selectFork(forkIdGoerli);
        vm.startBroadcast(privateKeyUserGoerli);
        Poked poked = new Poked();
        console2.log("poked: ");
        console2.log(address(poked));
        vm.stopBroadcast();
    }

    /**
     * @notice Sets the Poked's expected Suave stored private key.
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "setPokeExpectedSuaveKey()" --broadcast --legacy -vv
     */
    function setPokeExpectedSuaveKey() public {
        vm.selectFork(forkIdGoerli);
        vm.startBroadcast(privateKeyUserGoerli);
        Poked poked = Poked(POKED_DEPLOYED);
        poked.setSuapp(addressStoredSuapp);
        vm.stopBroadcast();
    }

    /**
     * @notice Deploys the PokeRelayer contract on Suave.
     * @dev note: Put this deployed address at the top of the file
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "deploySuavePokeRelayer()" --broadcast --legacy -vv 
     */
    function deploySuavePokeRelayer() public {
        vm.selectFork(forkIdSuave);
        vm.startBroadcast(privateKeyUserSuave);
        PokeRelayer pokeRelayer = new PokeRelayer(
            POKED_DEPLOYED,
            chainIdGoerli,
            gasNeededGoerliPoke
        );
        console2.log("addresss: ");
        console2.log(address(pokeRelayer));
    }

    /**
     * @notice Initializes the PokeRelayer's Confidential Control System
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "initializeConfidentialControl()" -vv 
     */
    function initializeConfidentialControl() public {
        vm.selectFork(forkIdSuave);
        // setup data for confidential compute request
        bytes32 secret = keccak256(abi.encode("secret")); // note: generate privately
        bytes memory confidentialInputs = abi.encodePacked(secret);
        bytes memory targetCall = abi.encodeWithSignature(
           "confidentialConstructor()"
        );

        uint64 nonce = vm.getNonce(addressUserSuave);
        console2.log("suave address nonce:");
        console2.log(nonce);
        ccrUtil.createAndSendCCR({
            signingPrivateKey: privateKeyUserSuave,
            confidentialInputs: confidentialInputs,
            targetCall: targetCall,
            nonce: nonce,
            to: POKE_RELAYER_DEPLOYED,
            gas: 10000000,
            gasPrice: 1000000000,
            value: 0,
            executionNode: addressKettle,
            chainId: uint256(0x01008C45)
        });
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
            to: POKE_RELAYER_DEPLOYED,
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
        bytes memory targetCall = abi.encodeWithSignature(
            "setGoerliUrl()"
        );
        uint64 nonce = vm.getNonce(addressUserSuave);
        ccrUtil.createAndSendCCR({
            signingPrivateKey: privateKeyUserSuave,
            confidentialInputs: confidentialInputs,
            targetCall: targetCall,
            nonce: nonce,
            to: POKE_RELAYER_DEPLOYED,
            gas: 1000000,
            gasPrice: 1000000000,
            value: 0,
            executionNode: addressKettle,
            chainId: uint256(0x01008C45)
        });
    }

    /**
     * @notice Performs a read on PokeRelayer's storage slots. 
     * @dev Useful for reading slot 5 which will hold the set DataIds for the confidential stores
     * @dev command: forge script script/Interactions.s.sol:Interactions -vv --sig "grabSlotSuapp(uint256)" 5
     */
    function grabSlotSuapp(uint256 slot) public {
        vm.selectFork(forkIdSuave);
        bytes32 value = vm.load(POKE_RELAYER_DEPLOYED, bytes32(slot));
        console2.log("slot: %d", slot);
        console2.logBytes32(value);
    }

    /**
     * @notice Crafts and signs a poke to be sent to Suave
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "sendPokeToSuave()" -vv  
     */
    function sendPokeToSuave() public {
        // make signed message from any private/public keyapir
        address user = addressPoking;
        uint256 userPk = privateKeyPoking;
        uint deadline = (vm.unixTime() / 1e3) + uint(200);

        // grab next poke nonce for user  
        vm.selectFork(forkIdGoerli);
        Poked poked = Poked(POKED_DEPLOYED);
        uint256 userNonce = poked.nonces(user);

        // sign over message
        (uint8 v, bytes32 r, bytes32 s) = _createPoke(user, userPk, deadline, userNonce); 

        // TODO Have suapp grab this price itself. Is a DoS vector if users
        // send transactions with too-low gas prices as it will cause the
        // transactions to pend.
        uint256 gasPrice = 1001;

        bytes memory confidentialInputs = abi.encode("");
        bytes memory targetCall = abi.encodeWithSignature(
            "newPokeBid(address,address,uint256,uint256,uint8,bytes32,bytes32,uint256)",
            user,
            addressStoredSuapp,
            deadline,
            userNonce,
            v,
            r,
            s,
            gasPrice
        );

        vm.selectFork(forkIdSuave);
        uint64 nonce = vm.getNonce(addressUserSuave);

        ccrUtil.createAndSendCCR({
            signingPrivateKey: privateKeyUserSuave,
            confidentialInputs: confidentialInputs,
            targetCall: targetCall,
            nonce: nonce,
            to: POKE_RELAYER_DEPLOYED,
            gas: 10000000,
            gasPrice: 1000000000,
            value: 0,
            executionNode: addressKettle,
            chainId: uint256(0x01008C45)
        });
    }

    /**
     * @notice Helper function for signing pokes.
     */
    function _createPoke(address user, uint256 userPk, uint256 deadline, uint256 userNonce) internal returns (uint8 v, bytes32 r, bytes32 s) {
        // setup SigUtils
        bytes32 POKE_TYPEHASH = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                POKE_TYPEHASH,
                keccak256(bytes("SuappCounter")),
                keccak256(bytes("1")),
                5,
                POKED_DEPLOYED 
            )
        );
        SigUtils sigUtils = new SigUtils(DOMAIN_SEPARATOR);

        SigUtils.Poke memory poke = SigUtils.Poke({
            user: user,
            permittedSuapp: addressStoredSuapp,
            deadline: deadline,
            nonce: userNonce
        });

        bytes32 digest = sigUtils.getTypedDataHash(poke);
        (v, r, s) = vm.sign(userPk, digest);   
    }
}
