# Only Suave Smart Contracts
OnlySUAPPCounter: [0x58840C1dA9cECB92399FcAbaD30f7d3dCF711cB9](https://goerli.etherscan.io/address/0x58840C1dA9cECB92399FcAbaD30f7d3dCF711cB9) 

ChainInfo: [0x84d3c27172dF56151a49925391E96eBF6Eb5EA2C](https://goerli.etherscan.io/address/0x84d3c27172dF56151a49925391E96eBF6Eb5EA2C)

Suapp: [0x58840C1dA9cECB92399FcAbaD30f7d3dCF711cB9](https://explorer.rigil.suave.flashbots.net/address/0x58840C1dA9cECB92399FcAbaD30f7d3dCF711cB9)

## Deploy commands
How to deploy goerli smart contracts:

OnlySUAPPCounter:
```
forge create --rpc-url xxx \
    --private-key xxx \
    --etherscan-api-key xxx \
    --verify \
    src/OnlySUAPPCounter.sol:OnlySUAPPCounter
```

ChainInfo:

```
forge create --rpc-url xxx \
    --private-key xxx \
    --etherscan-api-key xxx \
    --verify \
    src/ChainInfo.sol:ChainInfo
```


How to deploy SUAVE contracts:

SuaveSigner:
```
forge create --rpc-url https://rpc.rigil.suave.flashbots.net --legacy \
--constructor-args 0x58840C1dA9cECB92399FcAbaD30f7d3dCF711cB9 0x84d3c27172dF56151a49925391E96eBF6Eb5EA2C 5 "0x05" 2000000 \
--private-key xxx ./src/SuaveSigner.sol:SuaveSigner
```

## Contract Poking Commands
OnlySUAPPCounter : set suapp
```
cast send \
--private-key xxx \
--legacy \
--rpc-url xxx \
0x58840C1dA9cECB92399FcAbaD30f7d3dCF711cB9 \
"setSuapp(address)" "0x033FF54B2A7C70EeCB8976d910C055fAf952078a"
```

SuaveSigner:

Confidential Compute Request:

Non-CCR: