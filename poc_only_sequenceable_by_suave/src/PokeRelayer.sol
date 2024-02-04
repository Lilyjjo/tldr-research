// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Suave} from "suave-std/suavelib/Suave.sol";
import {Transactions} from "suave-std/Transactions.sol";
import {Bundle} from "suave-std/protocols/Bundle.sol";
import {LibString} from "../lib/suave-std/lib/solady/src/utils/LibString.sol";
import {ConfidentialControl} from "./utils/ConfidentialControl.sol";

contract PokeRelayer is ConfidentialControl {
    address public targetApp; //3
    address public gasContract;
    address public owner;

    Suave.DataId private signingKeyRecord; //6
    Suave.DataId private ethGoerliUrlRecord; 

    uint256 public chainId;
    uint256 public gasNeeded;
    uint256 public keyNonce;

    string public KEY_PRIVATE_KEY = "KEY";
    string public KEY_URL = "URL";

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

    function confidentialConstructor() public onlyOwner view override returns (bytes memory) {
        return super.confidentialConstructor();
    }

    function updateKeyNonce(uint256 keyNonce_) public onlyOwner {
        keyNonce = keyNonce_;
    }

    function updateGasNeeded(uint256 gasNeeded_) public onlyOwner {
        gasNeeded = gasNeeded_;
    }
    
    function updateKeyCallback(
        Suave.DataId signingKeyBid_,
        uint256 keyNonce_,
        UnlockArgs calldata uArgs
    ) external unlock(uArgs) {
        signingKeyRecord = signingKeyBid_;
        keyNonce = keyNonce_;
        emit UpdateKey(signingKeyRecord);
    }

    function setSigningKey(
        uint256 keyNonce_
    ) external view onlyOwner onlyConfidential returns (bytes memory) {
        require(Suave.isConfidential());
        bytes memory keyData = Suave.confidentialInputs();

        address[] memory peekers = new address[](1);
        peekers[0] = address(this);

        Suave.DataRecord memory bid = Suave.newDataRecord(
            10,
            peekers,
            peekers,
            "poke_relayer:v0:private_key"
        );
        Suave.confidentialStore(bid.id, KEY_PRIVATE_KEY, keyData);

        return
            abi.encodeWithSelector(
                this.updateKeyCallback.selector,
                bid.id, 
                keyNonce_, 
                getUnlockPair()
            );
    }

    function updateGoerliUrlCallback(
        Suave.DataId goerliKeyId,
        UnlockArgs calldata uArgs
    ) external unlock(uArgs) {
        ethGoerliUrlRecord = goerliKeyId;
    }

    function setGoerliUrl() external view onlyOwner onlyConfidential returns (bytes memory) {
        require(Suave.isConfidential());
        bytes memory keyData = Suave.confidentialInputs();

        address[] memory peekers = new address[](1);
        peekers[0] = address(this);

        // TODO: what do the decryption conditions mean?
        Suave.DataRecord memory bid = Suave.newDataRecord(
            10,
            peekers,
            peekers,
            "poke_relayer:v0:url"
        );
        Suave.confidentialStore(bid.id, KEY_URL, keyData);

        return
            abi.encodeWithSelector(
                this.updateGoerliUrlCallback.selector, bid.id, getUnlockPair()
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

    function updateNonceCallback(UnlockArgs calldata uArgs) external unlock(uArgs) {
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
    ) public payable onlyConfidential returns (bytes memory) {
        // grab signing key
        uint256 signingKey = uint256(
            bytes32(Suave.confidentialRetrieve(signingKeyRecord, KEY_PRIVATE_KEY))
        );

        // grab http URL
        string memory httpURL = string(Suave.confidentialRetrieve(ethGoerliUrlRecord, KEY_URL));
        
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

        // encode transaction 
        bytes memory rlpTxn = Transactions.encodeRLP(txn);

        // sign transaction with key
        bytes memory signedTxn = Suave.signEthTransaction(
            rlpTxn,
            LibString.toMinimalHexString(chainId),
            LibString.toHexStringNoPrefix(signingKey)
        );

        // send transaction over http json to stored enpoint 
        Suave.HttpRequest memory httpRequest = encodeEthSendRawTransaction(signedTxn, httpURL);
        Suave.doHTTPRequest(httpRequest);

        // update signing nonce in callback
        return
            abi.encodeWithSelector(
                this.updateNonceCallback.selector, getUnlockPair()
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
