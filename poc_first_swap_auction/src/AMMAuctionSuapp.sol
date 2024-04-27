// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Suave} from "suave-std/suavelib/Suave.sol";
import {Transactions} from "suave-std/Transactions.sol";
import {Bundle} from "./utils/Bundle.sol";
import {LibString} from "../lib/suave-std/lib/solady/src/utils/LibString.sol";
import {JSONParserLib} from "../lib/suave-std/lib/solady/src/utils/JSONParserLib.sol";
import {IAMMAuctionSuapp} from "./interfaces/IAMMAuctionSuapp.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

/**
 * @title AMMAuctionSuapp
 * @author lilyjjo
 */
contract AMMAuctionSuapp is IAMMAuctionSuapp {
    using JSONParserLib for *;

    // Auction Visibility/Functional Stats
    uint256 public ssalt; // for telling which CCR callback we're reading from
    uint256 public lastAuctionProcessedL1Block; //
    uint256 public nonceUsed;
    uint256 public includedTxns;
    uint256 private _notLandedButSent; //
    uint256 private _landed; //
    bool public bundleSuccess;
    uint256 public winningBidAmount;

    // Addresses
    address public targetAMM;
    address public targetDepositContract;
    address public targetAuctionGuard;
    address public owner;
    address public signingPubKey;

    uint256 public borderVar;

    /// @dev DataId for the signing key in Suave's confidential storage
    Suave.DataId private _signingKeyRecord;
    /// @dev DataId for the L1 URL in Suave's confidential storage
    Suave.DataId private _ethSepoliaUrlRecord; // 10
    /// @dev last block sent auction result for
    Suave.DataId private _lastBlockProcessedRecord;

    /// @dev ChainID for L1
    uint256 public chainId; // slot 11
    /// @dev Gas needed for auction result txn
    uint256 public gasNeededPostAuctionResults;
    /// @dev Time past last block's time to finish auction and send bundle
    uint256 public auctionDuration; // 9

    /// @dev Key for accessing the private key in Suave's confidential storage
    string public KEY_PRIVATE_KEY = "KEY";
    /// @dev Key for accessing the Ethereum Sepolia network URL in Suave's confidential storage
    string public KEY_URL = "URL";
    string public KEY_LAST_BLOCK_PROCESSED = "LAST_BLOCK";

    /// @dev bids for a block number
    /// @dev blockNumber => bids
    mapping(uint256 => Suave.DataId[]) private _blockBids;
    /// @dev normal transactions
    Suave.DataId[] private _nonBidTxns;

    /// @dev names spaces for confidential stores
    string public nonBidTxnNamespace = "non_bid_txns";
    string public bidNamespace = "bid_namespace";
    string public contractNamespace = "amm_generic_namespace";

    struct Bid {
        address bidder;
        uint256 blockNumber;
        uint256 amount;
        bytes swapTxn;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct Block {
        uint256 number;
        uint256 timestamp;
        uint256 baseFeePerGas;
    }

    /// @dev Error for when ownership is required
    error OnlyOwner();
    error StaleBid();
    error AuctionNotEnded();
    error AuctionAlreadyRan();

    /// @notice Emitted when the signing key is updated
    event UpdateKey(Suave.DataId newKey);
    event NonBidTxnId(address sender, Suave.DataId txnId);
    event NewBid(bytes32 saltedReturn, Suave.DataId bidId);

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
        address targetDepositContract_,
        address targetAuctionGuard_,
        uint256 chainId_,
        uint256 gasNeededPostAuctionResults_
    ) {
        owner = msg.sender;
        targetAMM = targetAMM_;
        targetDepositContract = targetDepositContract_;
        targetAuctionGuard = targetAuctionGuard_;
        chainId = chainId_;
        gasNeededPostAuctionResults = gasNeededPostAuctionResults_;
        auctionDuration = 1;
    }

    // let users (who aren't in auction) put their swaps into the system for inclusion
    function newPendingTxn() external returns (bytes memory) {
        bytes memory txnData = Suave.confidentialInputs();

        address[] memory allowedPeekers = new address[](1);
        allowedPeekers[0] = address(this);
        address[] memory allowedStores = new address[](1);
        allowedStores[0] = Suave.ANYALLOWED; // TODO: restrict this to a single kettle

        Suave.DataRecord memory txnRecord = Suave.newDataRecord(
            10,
            allowedPeekers,
            allowedStores,
            nonBidTxnNamespace
        );
        Suave.confidentialStore(txnRecord.id, nonBidTxnNamespace, txnData);
        return
            abi.encodeWithSelector(
                this.callbackNewPendingTxn.selector,
                msg.sender,
                txnRecord.id
            );
    }

    // TODO: add guard to keep people from calling
    function callbackNewPendingTxn(
        address sender,
        Suave.DataId txnId
    ) external {
        _nonBidTxns.push(txnId);
        emit NonBidTxnId(sender, txnId);
    }

    // lets people put new bids into txn
    function newBid(string memory salt) external returns (bytes memory) {
        Bid memory bid = abi.decode(Suave.confidentialInputs(), (Bid));

        uint256 lastBlockProcessed = uint256(
            bytes32(
                Suave.confidentialRetrieve(
                    _lastBlockProcessedRecord,
                    KEY_LAST_BLOCK_PROCESSED
                )
            )
        );

        string memory httpURL = string(
            Suave.confidentialRetrieve(_ethSepoliaUrlRecord, KEY_URL)
        );

        uint256 lastBlockSeen = _getLastL1BlockNumberUint(httpURL);

        if (
            bid.blockNumber <= lastBlockSeen ||
            bid.blockNumber == lastBlockProcessed
        ) revert StaleBid();

        // allowedPeekers: which contracts can read the record (only this contract)
        address[] memory allowedPeekers = new address[](1);
        allowedPeekers[0] = address(this);
        // allowedStores: which kettles can read the record (any kettle)
        address[] memory allowedStores = new address[](1);
        allowedStores[0] = Suave.ANYALLOWED; // TODO: restrict this to a single kettle

        Suave.DataRecord memory bidRecord = Suave.newDataRecord(
            10,
            allowedPeekers,
            allowedStores,
            bidNamespace
        );

        Suave.confidentialStore(bidRecord.id, bidNamespace, abi.encode(bid));
        bytes32 saltedReturn = keccak256(abi.encode(msg.sender, salt));

        return
            abi.encodeWithSelector(
                this.callbackNewBid.selector,
                bidRecord.id,
                bid.blockNumber,
                saltedReturn
            );
    }

    // TODO: add guard to keep people from calling
    function callbackNewBid(
        Suave.DataId bidId,
        uint256 blockNum,
        bytes32 saltedReturn
    ) external {
        _blockBids[blockNum].push(bidId);
        emit NewBid(saltedReturn, bidId);
    }

    function runAuction(uint256 salt) external returns (bytes memory) {
        // grab stored URL
        string memory httpURL = string(
            Suave.confidentialRetrieve(_ethSepoliaUrlRecord, KEY_URL)
        );

        // grab last L1 block's info
        Block memory lastL1Block = getLastL1Block(httpURL);

        // grab last auctioned block
        uint256 lastBlockAuctioned = uint256(
            bytes32(
                Suave.confidentialRetrieve(
                    _lastBlockProcessedRecord,
                    KEY_LAST_BLOCK_PROCESSED
                )
            )
        );

        // grab key's signing nonce
        uint256 nonce = _getSigningKeyNonce(httpURL);

        // bundles aren't guaranteed to land, send from last included index
        uint256 txsToSendIndex;
        if (nonceUsed != 0 && nonce > nonceUsed) {
            // we landed out last bundle, start from last sent
            txsToSendIndex = _notLandedButSent; // we did land, update
        } else {
            // we didn't land our bundle, resend transactions
            txsToSendIndex = _landed;
        }

        // TODO find more secure way to get current time
        // TODO write why this is a fundamental issue with design
        uint256 currentTime = _getCurrentTime();

        // check if time to run auction
        if (lastBlockAuctioned >= lastL1Block.number + 1)
            // don't double run an auction for a block
            revert AuctionAlreadyRan();
        if (currentTime < lastL1Block.timestamp + auctionDuration)
            revert AuctionNotEnded();

        uint256 currentBlock = lastL1Block.number + 1;

        // find auction winner
        (Bid memory winningBid, uint256 secondPrice) = _findAuctionWinner(
            currentBlock,
            lastL1Block,
            nonce,
            httpURL
        );
        uint256 auctionTxnCount = secondPrice == 0 ? 1 : 2;

        // construct bundle
        Bundle.BundleObj memory bundle;
        bundle.blockNumber = uint64(currentBlock);
        bundle.minTimestamp = 0;
        bundle.maxTimestamp = 0;
        uint256 nonBidTxnsCount = _nonBidTxns.length - txsToSendIndex;
        //bundle.revertingTxnsHash = new bytes32[](nonBidTxnsCount);
        bundle.txns = new bytes[](auctionTxnCount + nonBidTxnsCount);
        bundle.txns = new bytes[](auctionTxnCount + nonBidTxnsCount);

        if (auctionTxnCount == 2) {
            // include space for bid's swap txn
            bundle.txns[1] = winningBid.swapTxn;
        }

        // construct payment transaction
        bytes memory signedPaymentTxn = _createPostAuctionTransaction(
            winningBid,
            lastL1Block,
            secondPrice == 0 ? false : true,
            nonce
        );

        // add payment and bid transactions to bundle
        bundle.txns[0] = signedPaymentTxn;

        // add non-bid transactions
        uint256 includedTransactionCount = 0;
        for (uint i = txsToSendIndex; i < _nonBidTxns.length; i++) {
            bytes memory nonBidTxn = Suave.confidentialRetrieve(
                _nonBidTxns[i],
                nonBidTxnNamespace
            );
            bundle.txns[auctionTxnCount + includedTransactionCount] = nonBidTxn;
            //bundle.revertingTxnsHash[includedTransactionCount] = keccak256(
            //    nonBidTxn
            //);
            includedTransactionCount++;
        }

        // send bundle to flashbots
        bytes memory bundleRes = Bundle.sendBundle(
            "https://relay-holesky.flashbots.net",
            bundle
        );
        // send to titan too
        Bundle.sendBundle("http://holesky-rpc.titanbuilder.xyz/", bundle);

        // TODO figure out how to debug failing bundles
        //require(
        // this hex is '{"id":1,"result"'
        // close-enough way to check for successful sendBundle call
        //    bytes16(bundleRes) == 0x7b226964223a312c22726573756c7422,
        //    "bundle failed"
        //);

        // update confidential store's last ran block
        Suave.confidentialStore(
            _lastBlockProcessedRecord,
            KEY_LAST_BLOCK_PROCESSED,
            abi.encodePacked(currentBlock)
        );

        // send info to callback
        return
            abi.encodeWithSelector(
                this.callbackRunAuction.selector,
                txsToSendIndex + includedTransactionCount, // not landed but snet
                txsToSendIndex, // landed
                nonce,
                currentBlock,
                nonBidTxnsCount,
                secondPrice,
                bytes16(bundleRes) == 0x7b226964223a312c22726573756c7422
            );
    }

    function callbackRunAuction(
        uint256 notLandedButSent, // funcitonal
        uint256 landed, // functional
        uint256 nonceUsed_,
        uint256 auctioned_block,
        uint256 nonBidTxnsCount_,
        uint256 secondPrice_,
        bool bundleSuccess_
    ) external {
        // funcitonal
        _notLandedButSent = notLandedButSent;
        _landed = landed;

        // stats
        includedTxns = nonBidTxnsCount_;
        nonceUsed = nonceUsed_;
        lastAuctionProcessedL1Block = auctioned_block;
        winningBidAmount = secondPrice_;
        bundleSuccess = bundleSuccess_;
    }

    function _findAuctionWinner(
        uint256 blockNum,
        Block memory blockData,
        uint256 signingKeyNonce,
        string memory httpURL
    ) internal returns (Bid memory, uint256) {
        // filter through bids for last auction
        Suave.DataId[] storage bids = _blockBids[blockNum];

        uint256 bestPrice = 0;
        uint256 secondPrice;
        Bid memory bestBid;

        for (uint i = 0; i < bids.length; i++) {
            Bid memory bid = abi.decode(
                Suave.confidentialRetrieve(bids[i], bidNamespace),
                (Bid)
            );
            // check if bid passes simulation checks, if so, consider as valid bid
            bool passed = _simulateBid(
                bid,
                blockData,
                signingKeyNonce,
                httpURL
            );
            if (passed) {
                if (bid.amount > bestPrice) {
                    secondPrice = bestPrice;
                    bestPrice = bid.amount;
                    bestBid = bid;
                } else if (bid.amount > secondPrice) {
                    secondPrice = bid.amount;
                }
            }
        }
        if (secondPrice == 0) {
            // TODO: don't do this
            secondPrice = bestPrice;
        }

        return (bestBid, secondPrice);
    }

    function _simulateBid(
        Bid memory bid,
        Block memory blockData,
        uint256 signingKeyNonce,
        string memory httpURL
    ) internal returns (bool) {
        // check that bidder has enough funds to cover
        uint256 deposit = _ethCallUint(
            httpURL,
            targetDepositContract,
            abi.encodeWithSignature("balanceOf(address)", bid.bidder)
        );

        if (deposit < bid.amount) return false;

        // check that the withdraw and swap txns succeed
        // string memory id = Suave.newBuilder();

        // (1) simulate pulling payments
        bytes memory paymentTxn = _createPostAuctionTransaction(
            bid,
            blockData,
            true,
            signingKeyNonce
        );

        // TODO: wait for ferran to help debug Builder/Simulation API
        // If doesn't work, will need to write additional bid checking code

        return true;

        //Suave.SimulateTransactionResult memory simRes = Suave
        //    .simulateTransaction(id, paymentTxn);
        //require(simRes.success == true);
        //require(simRes.logs.length == 1);

        /*

        // check for success log
        bool foundPaymentSuccessLog;
        for (uint i = 0; i < simRes.logs.length; ++i) {
            Suave.SimulatedLog memory log = simRes.logs[i];
            if (log.addr == targetAMM) {
                for (uint j = 0; j < log.topics.length; j++) {
                    if (
                        log.topics[j] ==
                        keccak256(abi.encode("SuccessfulPayment"))
                    ) {
                        foundPaymentSuccessLog = true;
                        break;
                    }
                }
            }
            if (foundPaymentSuccessLog) break;
        }
        if (!foundPaymentSuccessLog) return false;

        // (2) simluate swap txn
        simRes = Suave.simulateTransaction(sessionId, paymentTxn);
        if (simRes.success = false) return false; // payment txn reverted

        bool foundSwapSuccessLog;
        for (uint i = 0; i < simRes.logs.length; ++i) {
            Suave.SimulatedLog memory log = simRes.logs[i];
            if (log.addr == targetAMM) {
                for (uint j = 0; j < log.topics.length; j++) {
                    if (
                        log.topics[j] ==
                        keccak256(abi.encode("AuctionSucceeded"))
                    ) {
                        foundSwapSuccessLog = true;
                        break;
                    }
                }
            }
            if (foundSwapSuccessLog) break;
        }
        if (!foundSwapSuccessLog) return false;

        // bid's execution is valid
        return true;
        */
    }

    function _createPostAuctionTransaction(
        Bid memory bid,
        Block memory blockData,
        bool auctionHasWinner,
        uint256 signingKeyNonce
    ) internal returns (bytes memory) {
        // create tx to sign with private key
        bytes memory targetCall = abi.encodeWithSignature(
            "postAuctionResults(address,uint256,uint256,bool,uint8,bytes32,bytes32)",
            bid.bidder,
            bid.blockNumber,
            bid.amount,
            auctionHasWinner,
            bid.v,
            bid.r,
            bid.s
        );

        // create transaction
        Transactions.EIP155Request memory txn = Transactions.EIP155Request({
            to: targetAuctionGuard,
            gas: gasNeededPostAuctionResults,
            gasPrice: blockData.baseFeePerGas + 800_000_000_000, // TODO figure out what to set this to
            value: 0,
            nonce: signingKeyNonce,
            data: targetCall,
            chainId: chainId
        });

        // encode transaction
        bytes memory rlpTxn = Transactions.encodeRLP(txn);

        // grab signing key
        uint256 signingKey = uint256(
            bytes32(
                Suave.confidentialRetrieve(_signingKeyRecord, KEY_PRIVATE_KEY)
            )
        );

        // sign transaction with key
        bytes memory signedTxn = Suave.signEthTransaction(
            rlpTxn,
            LibString.toMinimalHexString(chainId),
            LibString.toHexStringNoPrefix(signingKey)
        );

        return signedTxn;
    }

    function _getCurrentTime() internal returns (uint256) {
        Suave.HttpRequest memory request;
        request.method = "GET";
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        request.withFlashbotsSignature = false;
        request.url = "http://worldtimeapi.org/api/timezone/Etc/UTC";

        bytes memory result = Suave.doHTTPRequest(request);

        JSONParserLib.Item memory outerItem = string(result).parse();
        JSONParserLib.Item memory item = outerItem.at('"unixtime"');
        uint256 currentTime = JSONParserLib.parseUint(string(item.value()));

        return currentTime;
    }

    function getLastL1BlockNumber(
        string memory httpURL
    ) public returns (string memory) {
        Suave.HttpRequest memory request;
        request.method = "POST";
        request
            .body = '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}';
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        request.withFlashbotsSignature = false;
        request.url = httpURL;

        /// returns: {"jsonrpc":"2.0","id":1,"result":"0xa15714"}
        bytes memory result = Suave.doHTTPRequest(request);

        JSONParserLib.Item memory item = string(result).parse();
        string memory stringResult = trimQuotes(
            string(item.at('"result"').value())
        );

        return stringResult;
    }

    function _getLastL1BlockNumberUint(
        string memory httpURL
    ) internal returns (uint256) {
        return JSONParserLib.parseUintFromHex(getLastL1BlockNumber(httpURL));
    }

    function getLastL1Block(
        string memory httpURL
    ) public returns (Block memory blockData) {
        string memory blockNumber = getLastL1BlockNumber(httpURL);

        bytes memory body = abi.encodePacked(
            '{"method":"eth_getBlockByNumber","params":["',
            blockNumber,
            '",false],"id":1,"jsonrpc":"2.0"}'
        );

        Suave.HttpRequest memory request;
        request.method = "POST";
        request.body = body;
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        request.withFlashbotsSignature = false;
        request.url = httpURL;

        /// returns: https://docs.chainstack.com/reference/ethereum-getblockbynumber
        bytes memory result = Suave.doHTTPRequest(request);

        JSONParserLib.Item memory outerItem = string(result).parse();
        JSONParserLib.Item memory item = outerItem.at('"result"');

        blockData.baseFeePerGas = JSONParserLib.parseUintFromHex(
            trimQuotes(string(item.at('"baseFeePerGas"').value()))
        );
        blockData.timestamp = JSONParserLib.parseUintFromHex(
            trimQuotes(string(item.at('"timestamp"').value()))
        );
        blockData.number = JSONParserLib.parseUintFromHex(blockNumber);
    }

    function _getSigningKeyNonce(
        string memory httpURL
    ) internal returns (uint256) {
        bytes memory body = abi.encodePacked(
            '{"method":"eth_getTransactionCount","params":["',
            LibString.toHexString(signingPubKey),
            '", "latest"],"id":1,"jsonrpc":"2.0"}'
        );

        Suave.HttpRequest memory request;
        request.method = "POST";
        request.body = body;
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        request.withFlashbotsSignature = false;
        request.url = httpURL;

        /// returns: https://docs.chainstack.com/reference/ethereum-getblocktransactioncountbynumber
        bytes memory result = Suave.doHTTPRequest(request);

        JSONParserLib.Item memory item = string(result).parse();
        string memory stringResult = trimQuotes(
            string(item.at('"result"').value())
        );

        return JSONParserLib.parseUintFromHex(stringResult);
    }

    function _ethCallUint(
        string memory httpURL,
        address targetContract,
        bytes memory data
    ) internal returns (uint256) {
        bytes memory body = abi.encodePacked(
            '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"',
            LibString.toHexStringChecksummed(targetContract),
            '","data":"',
            LibString.toHexString(data),
            '"},"latest"],"id":1}'
        );

        Suave.HttpRequest memory request;
        request.method = "POST";
        request.body = body;
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        request.withFlashbotsSignature = false;
        request.url = httpURL;

        bytes memory result = Suave.doHTTPRequest(request);
        JSONParserLib.Item memory outerItem = string(result).parse();
        JSONParserLib.Item memory item = outerItem.at('"result"');
        return JSONParserLib.parseUintFromHex(trimQuotes(string(item.value())));
    }

    function trimQuotes(
        string memory input
    ) private pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        require(
            inputBytes.length >= 2 &&
                inputBytes[0] == '"' &&
                inputBytes[inputBytes.length - 1] == '"',
            "Invalid input"
        );

        bytes memory result = new bytes(inputBytes.length - 2);

        for (uint256 i = 1; i < inputBytes.length - 1; i++) {
            result[i - 1] = inputBytes[i];
        }

        return string(result);
    }

    /**
     * @notice Sets the signing key in Suave's confidential storage
     * @return bytes Encoded data for updating the key callback
     */
    function setSigningKey(
        address pubkey
    ) external onlyOwner returns (bytes memory) {
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
            contractNamespace
        );
        Suave.confidentialStore(bid.id, KEY_PRIVATE_KEY, keyData);

        return
            abi.encodeWithSelector(
                this.callbackSetSigningKey.selector,
                pubkey,
                bid.id
            );
    }

    /**
     * @notice Callback function to update the signing key record
     * @dev To be called as a Confidential Compute Callback.
     * @param signingKeyBid_ The new signing key record ID
     */
    function callbackSetSigningKey(
        address signingPubKey_,
        Suave.DataId signingKeyBid_
    ) external {
        signingPubKey = signingPubKey_;
        _signingKeyRecord = signingKeyBid_;
        emit UpdateKey(_signingKeyRecord);
    }

    /**
     * @notice Sets the Ethereum Sepolia network URL in Suave's confidential storage
     * @return bytes Encoded data for updating the Sepolia URL callback
     */
    function setSepoliaUrl() external onlyOwner returns (bytes memory) {
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
            contractNamespace
        );
        Suave.confidentialStore(bid.id, KEY_URL, keyData);

        return
            abi.encodeWithSelector(this.callbackSetSepoliaUrl.selector, bid.id);
    }

    /**
     * @notice Callback function to update the Sepolia network URL record
     * @dev To be called as a Confidential Compute Callback.
     * @param sepoliaKeyId The record ID for the Sepolia URL
     */
    function callbackSetSepoliaUrl(Suave.DataId sepoliaKeyId) external {
        _ethSepoliaUrlRecord = sepoliaKeyId;
    }

    /**
     * @notice Inits the data store for the last processed block
     * @return bytes Encoded data for updating the init L1 callback
     */
    function initLastL1Block() external onlyOwner returns (bytes memory) {
        require(Suave.isConfidential());

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
            contractNamespace
        );
        Suave.confidentialStore(
            bid.id,
            KEY_LAST_BLOCK_PROCESSED,
            abi.encode(0)
        );

        return
            abi.encodeWithSelector(
                this.callbackInitLastL1Block.selector,
                bid.id
            );
    }

    /**
     * @notice Callback function to init the last processed block data record
     * @dev To be called as a Confidential Compute Request.
     * @param lastL1BlockKeyId The record ID for the last processed block
     */
    function callbackInitLastL1Block(Suave.DataId lastL1BlockKeyId) external {
        _lastBlockProcessedRecord = lastL1BlockKeyId;
    }
}
