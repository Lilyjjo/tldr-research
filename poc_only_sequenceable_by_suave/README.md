# Only Sequenceable By Suave Proof of Concept
This proof of concept is designed to show a L1 smart contract that has portions of its functionality sequenced by Suave. 

Contracts include:
- Poked: A smart contract on Goerli that can receive EIP712 messages signed by users. Only a specified suapp is allowed to submit these messages to the Goerli contract.
- PokeRelayer: A suapp on Rigil that can relay EIP712 messages for users by sending transactions.
- GoerliChainInfo: A smart contrat on Goerli for grabbing the most recent block number. To be deprecated.


**Note:** The contracts are **not** safe from a security level. None of the callbacks have proper protections put in place yet.

# Smart Contract Deployments
Poked (Goerli): [0xB8d1d45Af8ffCF9d553b1B38907149f1Aa153378](https://goerli.etherscan.io/address/0xB8d1d45Af8ffCF9d553b1B38907149f1Aa153378) 

ChainInfo (Goerli): [0x6ED804B9d4FAAE9e092Fe6d73292151FCF5F0413](https://goerli.etherscan.io/address/0x6ED804B9d4FAAE9e092Fe6d73292151FCF5F0413)

PokeRelayer (Suapp): [0x95EC884355E4C9ea64825661c4BAf6F29Ea23da9](https://explorer.rigil.suave.flashbots.net/address/0x95EC884355E4C9ea64825661c4BAf6F29Ea23da9)

## Deployment Steps
To deploy/interact with the contracts:
1. Fill out the .env file with the needed variables. Note: if you do not have the needed funds in the different variables your code will not succeed.
2. Run the desired script functions in order to setup the contracts.

Recommended order of running due to script-generated address dependencies:
1. `deployGoerliContracts()` -> set POKE_RELAYER_DEPLOYED and CHAIN_INFO_DEPLOYED in Interactions.s.sol script
2. `deployPokeRelayer()` -> set POKE_RELAYER_DEPLOYED
3. `setSigningKey()`
4. `setGoerliRpcUrl()`
5. check that both confidential stores succeeded by checking their packed storage slot with: `grabSlotSuapp(uint256) 3`, successful calls will have both halfs of the bytes32 slot non-zero
6. `sendPokeToSuave()`

For example, running the command above the `setGoerliUrl()` function `Interactions.s.sol` will send a confidential compute request and call the function also named `setGoeliUrl()` in the Suapp on Suave: 
```
  /**
    forge script script/Interactions.s.sol:Interactions \
    --sig "setGoerliUrl()" -vv 
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
```