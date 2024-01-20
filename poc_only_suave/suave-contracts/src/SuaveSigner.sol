// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Suave} from "suave-std/suavelib/Suave.sol";
import {Transactions} from "suave-std/Transactions.sol";
import {Bundle} from "suave-std/protocols/Bundle.sol";
import "forge-std/console.sol";

contract SuaveSigner {
    address public targetApp;
    address public gasContract;
    address public owner;

    Suave.DataId private signingKeyRecord; // store is EDSCA key hex encoded without 0x prefix
    string public chainIdString; // hex encoded string with 0x prefix
    uint256 public chainId;
    uint256 public gasNeeded;
    uint256 private keyNonce;

    error OnlyOwner();
    error NotEnoughGasFee();

    event UpdateKey(Suave.DataId newKey);

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor(
        address targetApp_,
        address gasContract_,
        uint256 chainId_,
        string memory chainIdString_,
        uint256 gasNeeded_
    ) {
        owner = msg.sender;
        targetApp = targetApp_;
        gasContract = gasContract_;
        chainId = chainId_;
        chainIdString = chainIdString_;
        gasNeeded = gasNeeded_;
    }

    function updateKeyNonce(uint256 keyNonce_) public onlyOwner {
        keyNonce = keyNonce_;
    }

    function updateGasNeeded(uint256 gasNeeded_) public onlyOwner {
        gasNeeded = gasNeeded_;
    }

    function updateKeyCallback(
        Suave.DataId signingKeyBid_,
        uint256 keyNonce_
    ) external onlyOwner {
        signingKeyRecord = signingKeyBid_;
        keyNonce = keyNonce_;
        emit UpdateKey(signingKeyRecord);
    }

    function setSigningKey(
        uint256 keyNonce_
    ) external view onlyOwner returns (bytes memory) {
        require(Suave.isConfidential());
        bytes memory keyData = Suave.confidentialInputs();

        address[] memory peekers = new address[](1);
        peekers[0] = address(this);

        // TODO: what do the decryption conditions mean?
        Suave.DataRecord memory bid = Suave.newDataRecord(
            10,
            peekers,
            peekers,
            "SuaveSigner"
        );
        Suave.confidentialStore(bid.id, "keyData", keyData);

        return
            bytes.concat(
                this.updateKeyCallback.selector,
                abi.encode(bid.id, keyNonce_)
            );
    }

    function _getCurrentGasPrice() internal view returns (uint256 gasPrice) {
        bytes memory output = Suave.ethcall(
            gasContract,
            abi.encodeWithSignature("getGasPrice()")
        );
        gasPrice = abi.decode(output, (uint256));
    }

    function _getCurrentBlockNumber() internal view returns (uint256 gasPrice) {
        bytes memory output = Suave.ethcall(
            gasContract,
            abi.encodeWithSignature("getBlockNum()")
        );
        gasPrice = abi.decode(output, (uint256));
    }

    // TODO use guard functions from @halo3mic: https://github.com/halo3mic/suave-playground/blob/9afe269ab2da983ca7314b68fcad00134712f4c0/contracts/blockad/lib/ConfidentialControl.sol
    function updateNonceCallback() external {
        keyNonce++;
    }

    function newPokeBid(
        address user,
        address permittedSuapp,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable returns (bytes memory) {
        require(Suave.isConfidential());

        // require user sends in enough gas to cover cost
        uint256 gasPrice = _getCurrentGasPrice();
        uint256 gasFee = gasNeeded * gasPrice;
        if (gasFee < msg.value) {
            revert NotEnoughGasFee();
        }

        // create tx to sign with private key
        bytes memory targetCall = abi.encodeWithSignature(
            "poke(address,address,uint256,uint8,bytes32,bytes32)",
            user,
            permittedSuapp,
            deadline,
            v,
            r,
            s
        );

        // create transaction
        Transactions.EIP155Request memory txn = Transactions.EIP155Request({
            to: targetApp,
            gas: gasNeeded,
            gasPrice: gasPrice + 30,
            value: 0,
            nonce: keyNonce,
            data: targetCall,
            chainId: chainId
        });

        // grab signing key
        string memory signingKey = string(
            Suave.confidentialRetrieve(signingKeyRecord, "keyData")
        );

        // sign transaction with key
        bytes memory txnSigned = Suave.signEthTransaction(
            Transactions.encodeRLP(txn),
            chainIdString,
            signingKey
        );

        // submit txn to builder to be included
        uint256 currentBlockNum = _getCurrentBlockNumber();

        Bundle.BundleObj memory bundle;
        bundle.blockNumber = uint64(currentBlockNum + 2); // TODO idk what to set this to
        bundle.txns = new bytes[](1);
        bundle.txns[0] = txnSigned;

        Bundle.sendBundle("https://relay-goerli.flashbots.net", bundle);

        // update signing nonce in callback
        return bytes.concat(this.updateNonceCallback.selector);
    }
}
