// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Suave} from "./suave-imports/Suave.sol";
import {RLPEncoder} from "./utils/RLPEncoder.sol";
import "forge-std/console.sol";

contract SuaveSigner {
    address public targetApp;
    address public gasContract;
    address public owner;

    Suave.BidId private signingKeyBid; // store is EDSCA key hex encoded without 0x prefix
    string public chainIdString; // hex encoded string with 0x prefix
    uint256 public chainId;
    uint256 public gasNeeded;
    uint256 private keyNonce;

    error OnlyOwner();
    error NotEnoughGasFee();

    event UpdateKey(Suave.BidId newKey);

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
        Suave.BidId signingKeyBid_,
        uint256 keyNonce_
    ) external onlyOwner {
        signingKeyBid = signingKeyBid_;
        keyNonce = keyNonce_;
        emit UpdateKey(signingKeyBid);
    }

    function setSigningKey(
        uint256 keyNonce_
    ) external view onlyOwner returns (bytes memory) {
        require(Suave.isConfidential());
        bytes memory keyData = Suave.confidentialInputs();

        address[] memory peekers = new address[](1);
        peekers[0] = address(this);

        // TODO: what do the decryption conditions mean?
        Suave.Bid memory bid = Suave.newBid(
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

    function _rlpEncodeEIP1559Transaction(
        uint256 chainId_,
        uint256 keyNonce_,
        uint256 maxPriorityFeePerGas,
        uint256 maxFeePerGas,
        uint256 gasLimit,
        address destination,
        uint256 amount,
        bytes memory payload,
        bytes memory accessList
    ) internal returns (bytes memory txn) {
        // transaction byte format can be found at: https://eips.ethereum.org/EIPS/eip-1559
        bytes[] memory rlpEncodings = new bytes[](9);

        rlpEncodings[0] = RLPEncoder._rlpEncodeUint(chainId_);
        rlpEncodings[1] = RLPEncoder._rlpEncodeUint(keyNonce_);
        rlpEncodings[2] = RLPEncoder._rlpEncodeUint(maxPriorityFeePerGas);
        rlpEncodings[3] = RLPEncoder._rlpEncodeUint(maxFeePerGas);
        rlpEncodings[4] = RLPEncoder._rlpEncodeUint(gasLimit);
        rlpEncodings[5] = RLPEncoder._rlpEncodeAddress(destination);
        rlpEncodings[6] = RLPEncoder._rlpEncodeUint(amount);
        rlpEncodings[7] = RLPEncoder._rlpEncodeBytes(payload);
        rlpEncodings[8] = RLPEncoder._rlpEncodeBytes(accessList);

        bytes memory rlpTxn = RLPEncoder._rlpEncodeList(rlpEncodings);

        txn = new bytes(1 + rlpTxn.length);
        txn[0] = 0x02; // tx number for dynamic fee transactions

        for (uint i = 0; i < rlpTxn.length; ++i) {
            txn[i + 1] = rlpTxn[i];
        }
    }

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

        bytes memory txn = _rlpEncodeEIP1559Transaction(
            chainId,
            keyNonce,
            gasPrice /* maxPriorityFeePerGas */,
            gasPrice /* maxFeePerGas */,
            gasNeeded * 2 /* gas limit */,
            targetApp,
            0 /* value */,
            targetCall,
            new bytes(0) /* access list */
        );

        // grab signing key
        string memory signingKey = string(
            Suave.confidentialRetrieve(signingKeyBid, "keyData")
        );

        // sign transaction with key
        bytes memory txnSigned = Suave.signEthTransaction(
            txn,
            chainIdString,
            signingKey
        );

        // submit txn to builder to be included
        Suave.submitBundleJsonRPC("rpcUrl", "method", "params");

        // update signing nonce in callback
        return bytes.concat(this.updateNonceCallback.selector);
    }
}
