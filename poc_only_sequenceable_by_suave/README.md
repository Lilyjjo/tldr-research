# Only Sequenceable By Suave Proof of Concept
This proof of concept is designed to show a L1 smart contract that has portions of its functionality sequenced by Suave. 

Contracts include:
- Poked: A smart contract on Goerli that can receive EIP712 messages signed by users. Only a specified suapp is allowed to submit these messages to the Goerli contract.
- PokeRelayer: A suapp on Rigil that can relay EIP712 messages for users.


**Note:** The contracts are **not** fully tested. Currently they can be deployed and have some functionality played with, but their main functionality is not finished. This is next on my TODO list. :)

# Smart Contract Deployments
Poked (Goerli): [0x7CDd4e7Aa349b5d13189ef3D162eb2EDA25F126C](https://goerli.etherscan.io/address/0x7CDd4e7Aa349b5d13189ef3D162eb2EDA25F126C) 

ChainInfo (Goerli): [0x5941218c1D4FA0f25611D6c71Fe3bd966f6bbE2b](https://goerli.etherscan.io/address/0x5941218c1D4FA0f25611D6c71Fe3bd966f6bbE2b)
- note: is going to be refactored out 

PokeRelayer (Suapp): [0xEB2629402890d732330bB025BE4968b07EcF6B7b](https://explorer.rigil.suave.flashbots.net/address/0xEB2629402890d732330bB025BE4968b07EcF6B7b)

## Deployment Steps
To deploy/interact with the contracts:
1. Fill out the .env file with the needed variables. Note: some of the variables can only be obtained by running the script.
2. Run the desired script function by running the terminal command above the function.

Recommended order of running due to script-generated address dependencies:
1. `deployGoerliContracts()` 
2. `deployPokeRelayer()`
3. `setSigningKey()`

For example, running the command above the `setSigningKey()` function will send a CCR to the configured suave endpoint: 
```
 /**
    forge script \
    script/Interactions.s.sol:Interactions \
    --rpc-url rigil \
    --sig "setSigningKey(uint256)" 1 \
    -vv \
    --via-ir    
     */
    function setSigningKey(uint256 signingKeyNonce) public {
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
```