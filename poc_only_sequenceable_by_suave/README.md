# Only Sequenceable By Suave Proof of Concept
This proof of concept is designed to show a L1 smart contract that has portions of its functionality sequenced by Suave. 

Contracts include:
- Poked: A smart contract on Sepolia that can receive EIP712 messages signed by users. Only a specified private key, stored suapp, is allowed to submit these messages to the Sepolia contract.
- PokeRelayer: A suapp on Rigil, with the private key, that can relay EIP712 messages for users by sending transactions.

## Logic Flow
A user signs a `Poke` EIP712 message and submits it to the `PokeRelayer` contract via a confidential compute request. The `PokeRelayer` constructs and signs a transaction carrying the `Poke` and sends the transaction to Sepolia. The `Poked` contract on Sepolia receives the transaction and updates the original user's nonce. 

# Smart Contract Deployments
Poked (Sepolia): [0xB8d1d45Af8ffCF9d553b1B38907149f1Aa153378](https://sepolia.etherscan.io/address/0xB8d1d45Af8ffCF9d553b1B38907149f1Aa153378) 

PokeRelayer (Suapp): [0xe1936a1de5f2f311F1d69254bd22C94F47610A63](https://explorer.rigil.suave.flashbots.net/address/0xe1936a1de5f2f311F1d69254bd22C94F47610A63)

## Repo Information
This is a Foundry repo. All of the code to interact with the smart contracts is found in the script `Interactions.s.sol`. To use this repo fill out the needed environment variables. 

This repo supports sending CCRs to both Rigil and local devnets. You can toggle between the two modes using the env var `USE_RIGIL`. If using the local devnet, make sure you node has `http` requests enabled.

Note: Foundry currently doesn't support sending custom transaction types. In order to be able to send Confidential Compute Requests, this the repo uses Foundry's `vm.rpc('eth_sendRawTransaction', "["0x..."]")`. The logic for this is in `CCRForgeUtil.sol`. It is a little jank and successful CCRs will fail with `Script Error` while actual failed CCRs will fail with an actual error response. I'm debugging why right now.

To deploy/interact with the contracts:
1. Fill out the `.env` file with the needed variables.
2. Run the script function in order.

Recommended order of functions:
1. `deployPoke()` -> set `POKED_DEPLOYED` at top of Interactions.s.sol script.
2. `setPokeExpectedSuaveKey()` 
3. `deploySuavePokeRelayer()` -> set `POKE_RELAYER_DEPLOYED`.
4. `initializeConfidentialControl()`
5. `setSigningKey()`
6. `setSepoliaRpcUrl()`
7. Check that both confidential stores succeeded by checking their packed storage slot with: `grabSlotSuapp(uint256) 5`, successful calls will have both halfs of the bytes32 slot non-zero.
8. `sendPokeToSuave()` -> check on Sepolia to see the poke 

The needed commands for the script are above the script functions in the Interactions.s.sol file. For example, running the command above the `deployPoke()` function will run the function.
```
   /**
    * @notice Deploys the Poke contract to Sepolia.
    * @dev note: Put this deployed address at the top of the file
    * @dev command: forge script script/Interactions.s.sol:Interactions --sig "deployPoke()" --broadcast --legacy -vv --verify
    */
    function deployPoke() public {
        vm.selectFork(forkIdSepolia);
        vm.startBroadcast(privateKeyUserSepolia);
        Poked poked = new Poked();
        console2.log("poked: ");
        console2.log(address(poked));
        vm.stopBroadcast();
    }
```