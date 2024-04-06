// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Suave} from "suave-std/suavelib/Suave.sol";
import {Transactions} from "suave-std/Transactions.sol";
import {Bundle} from "suave-std/protocols/Bundle.sol";
import {LibString} from "../lib/suave-std/lib/solady/src/utils/LibString.sol";
import {ConfidentialControl} from "./utils/ConfidentialControl.sol";

/**
 * @title PokeRelayer Suave App
 * @author lilyjjo
 * @dev Relays a specific EIP712 signed message to a target L1 app.
 * @dev To be deployed on the Suave chain.
 */
contract PokeRelayer is ConfidentialControl {
    /// @notice Target L1 smart contract address for relayed transactions
    address public targetApp;
    /// @notice Contract owner address
    address public owner;

    /// @dev DataId for the signing key in Suave's confidential storage
    Suave.DataId private signingKeyRecord;
    /// @dev DataId for the L1 URL in Suave's confidential storage
    Suave.DataId private ethSepoliaUrlRecord;

    /// @notice ChainID for L1
    uint256 public chainId;
    /// @notice Gas needed for L1 transaction
    uint256 public gasNeeded;
    /// @notice L1 nonce for the pk in storage used to sign transactions
    uint256 public keyNonce;

    /// @dev Key for accessing the private key in Suave's confidential storage
    string public KEY_PRIVATE_KEY = "KEY";
    /// @dev Key for accessing the Ethereum Sepolia network URL in Suave's confidential storage
    string public KEY_URL = "URL";

    /// @dev Error for when ownership is required
    error OnlyOwner();

    /// @notice Emitted when the signing key is updated
    event UpdateKey(Suave.DataId newKey);

    /// @dev Modifier to restrict function calls to the contract owner
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    /**
     * @notice Constructs the PokeRelayer contract
     * @param targetApp_ Address of the target application for the relayed transactions
     * @param chainId_ ID of the blockchain where the targetApp is deployed
     * @param gasNeeded_ Gas amount required for L1 Poke transaction
     */
    constructor(address targetApp_, uint256 chainId_, uint256 gasNeeded_) {
        owner = msg.sender;
        targetApp = targetApp_;
        chainId = chainId_;
        gasNeeded = gasNeeded_;
    }

    /**
     * @notice Initializes confidential settings for the contract
     * @dev Needs to be called before the other Confidential Request Callbacks
     * are made.
     * @return bytes Encoded confidential initialization data
     */
    function confidentialConstructor()
        public
        view
        override
        onlyOwner
        returns (bytes memory)
    {
        return super.confidentialConstructor();
    }

    /**
     * @notice Updates the L1 nonce used with the signing key
     * @param keyNonce_ The new nonce value
     */
    function updateKeyNonce(uint256 keyNonce_) public onlyOwner {
        keyNonce = keyNonce_;
    }

    /**
     * @notice Updates the gas amount required for the L1 transactions
     * @param gasNeeded_ The new gas amount
     */
    function updateGasNeeded(uint256 gasNeeded_) public onlyOwner {
        gasNeeded = gasNeeded_;
    }

    /**
     * @notice Callback function to update the signing key record
     * @dev To be called as a Confidential Compute Callback.
     * @param signingKeyBid_ The new signing key record ID
     * @param keyNonce_ The updated nonce value
     * @param uArgs Unlock arguments for the operation
     */
    function updateKeyCallback(
        Suave.DataId signingKeyBid_,
        uint256 keyNonce_,
        UnlockArgs calldata uArgs
    ) external unlock(uArgs) {
        signingKeyRecord = signingKeyBid_;
        keyNonce = keyNonce_;
        emit UpdateKey(signingKeyRecord);
    }

    /**
     * @notice Sets the signing key in Suave's confidential storage
     * @param keyNonce_ The nonce associated with the signing key
     * @return bytes Encoded data for updating the key callback
     */
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

    /**
     * @notice Callback function to update the Sepolia network URL record
     * @dev To be called as a Confidential Compute Callback.
     * @param sepoliaKeyId The record ID for the Sepolia URL
     * @param uArgs Unlock arguments for the operation
     */
    function updateSepoliaUrlCallback(
        Suave.DataId sepoliaKeyId,
        UnlockArgs calldata uArgs
    ) external unlock(uArgs) {
        ethSepoliaUrlRecord = sepoliaKeyId;
    }

    /**
     * @notice Sets the Ethereum Sepolia network URL in Suave's confidential storage
     * @return bytes Encoded data for updating the Sepolia URL callback
     */
    function setSepoliaUrl()
        external
        view
        onlyOwner
        onlyConfidential
        returns (bytes memory)
    {
        require(Suave.isConfidential());
        bytes memory keyData = Suave.confidentialInputs();

        address[] memory peekers = new address[](1);
        peekers[0] = address(this);

        Suave.DataRecord memory bid = Suave.newDataRecord(
            10,
            peekers,
            peekers,
            "poke_relayer:v0:url"
        );
        Suave.confidentialStore(bid.id, KEY_URL, keyData);

        return
            abi.encodeWithSelector(
                this.updateSepoliaUrlCallback.selector,
                bid.id,
                getUnlockPair()
            );
    }

    /**
     * @notice Callback function to increment the signing key's nonce
     * @dev To be called as a Confidential Compute Callback.
     * @param uArgs Unlock arguments for the operation
     */
    function updateNonceCallback(
        UnlockArgs calldata uArgs
    ) external unlock(uArgs) {
        keyNonce++;
    }

    /**
     * @notice Relays the Poke's signed message components as a transaction to L1
     * @param user Address of the user signing the poke
     * @param permittedSuapp Address of the permitted Suapp (the PK stored)
     * @param deadline Deadline for the poke bid
     * @param nonce Nonce for the poke on L1 (nonce in Poked contract for user)
     * @param v Component of the signature
     * @param r Component of the signature
     * @param s Component of the signature
     * @param gasPrice Gas price for the transaction
     * @return bytes Encoded data for updating the nonce callback
     */
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
            bytes32(
                Suave.confidentialRetrieve(signingKeyRecord, KEY_PRIVATE_KEY)
            )
        );

        // grab http URL
        string memory httpURL = string(
            Suave.confidentialRetrieve(ethSepoliaUrlRecord, KEY_URL)
        );

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
        Suave.HttpRequest memory httpRequest = encodeEthSendRawTransaction(
            signedTxn,
            httpURL
        );
        Suave.doHTTPRequest(httpRequest);

        // update signing nonce in callback
        return
            abi.encodeWithSelector(
                this.updateNonceCallback.selector,
                getUnlockPair()
            );
    }

    /**
     * @dev Encodes the Ethereum transaction for sending via HTTP request
     * @param signedTxn The signed transaction bytes
     * @param url The URL to send the transaction to
     * @return Suave.HttpRequest Struct containing HTTP request information
     */
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
