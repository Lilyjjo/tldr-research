// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Suave} from "suave-std/suavelib/Suave.sol";
import {Transactions} from "suave-std/Transactions.sol";
import {Bundle} from "suave-std/protocols/Bundle.sol";
import {LibString} from "../lib/suave-std/lib/solady/src/utils/LibString.sol";
import "forge-std/console.sol";

contract PokeRelayer {
    address public targetApp;
    address public gasContract;
    address public owner;

    Suave.DataId public signingKeyRecord;
    Suave.DataId public ethGoerliUrlRecord; 
    uint256 public chainId;
    uint256 public gasNeeded;
    uint256 public keyNonce;

    event SignedTxn(bytes signedTxn);

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
        uint256 gasNeeded_
    ) {
        owner = msg.sender;
        targetApp = targetApp_;
        gasContract = gasContract_;
        chainId = chainId_;
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
    ) external {
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

    function updateGoerliUrl(
        Suave.DataId goerliKeyId
    ) external onlyOwner {
        ethGoerliUrlRecord = goerliKeyId;
    }

    function setGoerliUrl() external view onlyOwner returns (bytes memory) {
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
        Suave.confidentialStore(bid.id, "urlData", keyData);

        return
            bytes.concat(
                this.updateGoerliUrl.selector, abi.encode(bid.id)
            );
    }

    function _getCurrentGasPrice() internal view returns (uint256 gasPrice) {
        bytes memory output = Suave.ethcall(
            gasContract,
            abi.encodeWithSignature("getGasPrice()")
        );
        gasPrice = abi.decode(output, (uint256));
    }

    function _getCurrentBlockNumber() internal view returns (uint256 blockNum) {
        bytes memory output = Suave.ethcall(
            gasContract,
            abi.encodeWithSignature("getBlockNum()")
        );
        blockNum = abi.decode(output, (uint256));
    }

    // TODO use guard functions from @halo3mic: https://github.com/halo3mic/suave-playground/blob/9afe269ab2da983ca7314b68fcad00134712f4c0/contracts/blockad/lib/ConfidentialControl.sol
    function updateNonceCallback() external {
        keyNonce++;
    }

    function newPokeBid(
        address user,
        address permittedSuapp,
        uint256 deadline,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 gasPrice
    ) public payable returns (bytes memory) {
        // grab signing key
        uint256 signingKey = uint256(
            bytes32(Suave.confidentialRetrieve(signingKeyRecord, "keyData"))
        );

        // grab http URL
        string memory httpURL = string(Suave.confidentialRetrieve(ethGoerliUrlRecord, "urlData"));
        
        // create tx to sign with private key
        bytes memory targetCall = abi.encodeWithSignature(
            "poke(address,address,uint256,uint256,uint8,bytes32,bytes32)",
            user,
            permittedSuapp,
            deadline,
            nonce,
            v,
            r,
            s
        );

        // create transaction
        Transactions.EIP155Request memory txn = Transactions.EIP155Request({
            to: targetApp,
            gas: gasNeeded,
            gasPrice: gasPrice,
            value: 0,
            nonce: keyNonce,
            data: targetCall,
            chainId: chainId
        });

        
        bytes memory rlpTxn = Transactions.encodeRLP(txn);

        // sign transaction with key
        bytes memory signedTxn = Suave.signEthTransaction(
            rlpTxn,
            LibString.toMinimalHexString(chainId),
            LibString.toHexStringNoPrefix(signingKey)
        );

        Suave.HttpRequest memory httpRequest = encodeEthSendRawTransaction(signedTxn, httpURL);
        Suave.doHTTPRequest(httpRequest);

        // update signing nonce in callback
        return
            bytes.concat(
                this.updateNonceCallback.selector
            );
    }

    function encodeEthSendRawTransaction(
       bytes memory signedTxn,
       string memory url
    ) internal pure returns (Suave.HttpRequest memory) {

         bytes memory body = abi.encodePacked(
            '{"jsonrpc":"2.0","method":"eth_sendRawTransaction","params":["',
            LibString.toHexString(signedTxn),
            '"],"id":1}'
        );

        Suave.HttpRequest memory request;
        request.method = "POST";
        request.body = body;
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        request.withFlashbotsSignature = false;
        request.url = url;

        return request;
    }
}
