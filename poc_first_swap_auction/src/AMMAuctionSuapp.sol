// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Suave} from "suave-std/suavelib/Suave.sol";
import {Transactions} from "suave-std/Transactions.sol";
import {Bundle} from "suave-std/protocols/Bundle.sol";
import {LibString} from "../lib/suave-std/lib/solady/src/utils/LibString.sol";

/**
 * @title AMMAuctionSuapp 
 * @author lilyjjo
 * @dev 
 * @dev
 */
contract AMMAuctionSuapp {
    /// @notice Target L1 smart contract address for relayed transactions
    address public targetAMM;
    /// @notice Contract owner address
    address public owner;

    /// @dev last block sent auction result for
    uint256 lastBlockProcessed;

    /// @dev bids for a block number 
    /// @dev blockNumber => bids
    mapping(uint256 => bytes32[]) private _blockBids;  

    /// @dev DataId for the signing key in Suave's confidential storage
    Suave.DataId private _signingKeyRecord;
    /// @dev DataId for the L1 URL in Suave's confidential storage
    Suave.DataId private _ethGoerliUrlRecord; 
    /// @dev DataId for the L1 URL in Suave's confidential storage

    /// @notice ChainID for L1
    uint256 public chainId;

    /// @dev Key for accessing the private key in Suave's confidential storage
    string public KEY_PRIVATE_KEY = "KEY";
     /// @dev Key for accessing the Ethereum Goerli network URL in Suave's confidential storage
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
     * @param targetAMM_ Address of the target application for the relayed transactions
     * @param chainId_ ID of the blockchain where the targetApp is deployed
     */
    constructor(
        address targetAMM_,
        uint256 chainId_
    ) {
        owner = msg.sender;
        targetAMM = targetAMM_;
        chainId = chainId_;
    }


    /**
     * @notice Callback function to update the signing key record
     * @dev To be called as a Confidential Compute Callback.
     * @param signingKeyBid_ The new signing key record ID
     */ 
    function updateKeyCallback(
        Suave.DataId signingKeyBid_
    ) external {
        _signingKeyRecord = signingKeyBid_;
        emit UpdateKey(_signingKeyRecord);
    }

    /**
     * @notice Sets the signing key in Suave's confidential storage
     * @return bytes Encoded data for updating the key callback
     */
    function setSigningKey() external onlyOwner returns (bytes memory) {
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
                bid.id 
            );
    }

    /**
     * @notice Callback function to update the Goerli network URL record
     * @dev To be called as a Confidential Compute Callback.
     * @param goerliKeyId The record ID for the Goerli URL
     */
    function updateGoerliUrlCallback(
        Suave.DataId goerliKeyId
    ) external {
        _ethGoerliUrlRecord = goerliKeyId;
    }

    /**
     * @notice Sets the Ethereum Goerli network URL in Suave's confidential storage
     * @return bytes Encoded data for updating the Goerli URL callback
     */
    function setGoerliUrl() external onlyOwner returns (bytes memory) {
        require(Suave.isConfidential());
        bytes memory keyData = Suave.confidentialInputs();

        // allowedPeekers: which contracts can read the record (only this contract)
        address[] memory allowedPeekers = new address[](1);
        allowedPeekers[0] = address(this);
        // allowedStores: which kettles can read the record (any kettle)
        address[] memory allowedStores = new address[](1);
        allowedStores[0] = Suave.ANYALLOWED;

        Suave.DataRecord memory bid = Suave.newDataRecord(
            10,
            allowedPeekers,
            allowedStores,
            "poke_relayer:v0:url"
        );
        Suave.confidentialStore(bid.id, KEY_URL, keyData);

        return
            abi.encodeWithSelector(
                this.updateGoerliUrlCallback.selector, bid.id
            );
    }


    // let swappers (who aren't in auction) put their swaps into the system for inclusion
    // input: signed transaction
    // output: signed transaction either in CS or on-chain for auction result to post
    // note: on-chain will have 4 second lag
    //       off-chain will just be harder accounting wise
    //       note: figure out if we can remove things frmo the confidential store??
    //
    // CCR or transaction will depend on where we're storing the swaps 
    function newPendingSwap() external returns(bytes memory) {
        // confidential inputs should be 
    }

    // make so anyone can call?
    // step through the auction:
    //   finish last auction if one was running and the end time has hit
    //      - send winning bundle 
    //      - start new auction
    // if doing CCR need to start and stay here 
    // 2nd price auction 
    function runAuction() public returns (bytes memory) {
        // grab block time, see if need to finish last auction

        // if not time, do nothing

        // if time to run auction
        // run through bids for block number
        // determine 2nd price winner
        // make bundle with winner
    }


    function newBid() external returns (bytes memory) {}
    // cs params:
    // target block number
    // payment amount
    // swap to run
    // output: bid ID

    function updateBid() external returns (bytes memory) {}
    // input: param id to update
    // input: new params



    /**
     * @dev Encodes the Ethereum transaction for sending via HTTP request
     * @param signedTxn The signed transaction bytes
     * @param url The URL to send the transaction to
     * @return Suave.HttpRequest Struct containing HTTP request information
     */
    function _encodeEthSendRawTransaction(
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
