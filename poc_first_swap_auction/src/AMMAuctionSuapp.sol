// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Suave} from "suave-std/suavelib/Suave.sol";
import {Transactions} from "suave-std/Transactions.sol";
import {Bundle} from "./utils/Bundle.sol";
import {LibString} from "../lib/suave-std/lib/solady/src/utils/LibString.sol";
import "forge-std/console.sol";

/**
 * @title AMMAuctionSuapp 
 * @author lilyjjo
 * @dev 
 * @dev
 */
contract AMMAuctionSuapp {
    /// @notice Target L1 AuctionedAMM 
    address public targetAMM;
    /// @notice Target L1 deposit contract for AuctionAMM
    address public targetDepositContract;
    /// @notice Contract owner address
    address public owner;

    /// @dev DataId for the signing key in Suave's confidential storage
    Suave.DataId private _signingKeyRecord;
    /// @dev DataId for the L1 URL in Suave's confidential storage
    Suave.DataId private _ethGoerliUrlRecord; 
    /// @dev last block sent auction result for
    Suave.DataId private _lastBlockProcessedRecord;

    /// @dev ChainID for L1
    uint256 public chainId;
    /// @dev Gas needed for auction result txn
    uint256 public gasNeededPostAuctionResults;
    /// @dev Gas price for auction result txn
    uint256 public gasPrice; // TODO: pull somehow 
    /// @dev Nonce to use for Suapp's signing key 
    uint256 public signingKeyNonce; 
    /// @dev Time past last block's time to finish auction and send bundle
    uint256 public auctionDuration;

    /// @dev Key for accessing the private key in Suave's confidential storage
    string public KEY_PRIVATE_KEY = "KEY";
     /// @dev Key for accessing the Ethereum Goerli network URL in Suave's confidential storage
    string public KEY_URL = "URL";
    string public KEY_LAST_BLOCK_PROCESSED = "LAST_BLOCK";
    

    /// @dev bids for a block number 
    /// @dev blockNumber => bids
    mapping(uint256 => Suave.DataId[]) private _blockBids;  

    /// @dev normal transactions
    Suave.DataId[] private _nonBidTxns;
    uint256 public nextTxnIndexToInclude;

    /// @dev names spaces for confidential stores
    string public nonBidTxnNamespace = "non_bid_txns";
    string public bidNamespace = "bid_namespace";
    string public contractNamespace = "amm_generic_namespace";


    struct Bid {
        address bidder;
        uint256 blockNumber;
        uint256 payment;
        bytes swapTxn;
        bytes withdrawEIP712;
        uint8 v;
        bytes32 r;
        bytes32 s;
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
        uint256 chainId_,
        uint256 gasNeededPostAuctionResults_,
        uint256 gasPrice_
    ) {
        owner = msg.sender;
        targetAMM = targetAMM_;
        targetDepositContract = targetDepositContract_;
        chainId = chainId_;
        gasNeededPostAuctionResults = gasNeededPostAuctionResults_;
        gasPrice = gasPrice_; // todo: have this update itself
    }


    // let users (who aren't in auction) put their swaps into the system for inclusion
    function newPendingTxn() external returns(bytes memory) {
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
        return abi.encodeWithSelector(this.callbackNewPendingTxn.selector, msg.sender, txnRecord.id);
    }

    // TODO: add guard to keep people from calling
    function callbackNewPendingTxn(address sender, Suave.DataId txnId) external {
        _nonBidTxns.push(txnId);
        emit NonBidTxnId(sender, txnId);
    }

    // lets people put new bids into txn
    function newBid(uint salt) external returns (bytes memory) {
        Bid memory bid = abi.decode(Suave.confidentialInputs(), (Bid));
        uint256 lastBlockProcessed = uint256(bytes32(Suave.confidentialRetrieve(_lastBlockProcessedRecord, KEY_LAST_BLOCK_PROCESSED)));

        if(bid.blockNumber <= _getLastL1BlockNumber() || bid.blockNumber == lastBlockProcessed) revert StaleBid();

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

        return abi.encodeWithSelector(this.callbackNewBid.selector, bidRecord.id, bid.blockNumber, saltedReturn);
    }

    // TODO: add guard to keep people from calling
    function callbackNewBid(Suave.DataId bidId, uint256 blockNum, bytes32 saltedReturn) external {
        _blockBids[blockNum].push(bidId);
        emit NewBid(saltedReturn, bidId);
    }

    function runAuction() external returns (bytes memory) {
        // grab last L1 block's info
        (uint256 lastL1Block, uint256 lastL1BlockTime) = _getLastL1BlockInfo();
        // grab last auctioned block
        uint256 lastBlockAuctioned = uint256(
            bytes32(Suave.confidentialRetrieve(_lastBlockProcessedRecord, KEY_LAST_BLOCK_PROCESSED))
        );
        uint256 currentTime = block.timestamp; // TODO what does this return in a CCR?
        
        // check if time to run auction 
        if(lastBlockAuctioned >= lastL1Block) revert AuctionAlreadyRan();
        if(currentTime < lastL1BlockTime + auctionDuration) revert AuctionNotEnded();

        uint256 currentBlock = lastL1Block + 1;

        // find auction winner
        (Bid memory winningBid, uint256 secondPrice) = _findAuctionWinner(currentBlock);

        // construct bundle
        Bundle.BundleObj memory bundle;
        bundle.blockNumber = uint64(currentBlock);
        uint256 nonBidTxnsCount = _nonBidTxns.length - nextTxnIndexToInclude;
        bundle.txns = new bytes[](2 + nonBidTxnsCount);
        bundle.revertingTxnsHash = new bytes32[](nonBidTxnsCount);

        // construct payment transaction
        bytes memory signedPaymentTxn = _createPostAuctionTransaction(winningBid, secondPrice == 0 ? false : true);

        // add payment and bid transactions to bundle
        bundle.txns[0] = signedPaymentTxn;
        bundle.txns[1] = winningBid.swapTxn;

        // add non-bid transactions
        uint256 includedTransactionCount = 0;
        for(uint i = nextTxnIndexToInclude; i < _nonBidTxns.length; i++) {
            bytes memory nonBidTxn = Suave.confidentialRetrieve(_nonBidTxns[i], nonBidTxnNamespace);
            bundle.txns[2 + includedTransactionCount] = nonBidTxn;
            bundle.revertingTxnsHash[includedTransactionCount] = keccak256(nonBidTxn);
            includedTransactionCount++;
        }

        // send bundle
        bytes memory bundleRes = Bundle.sendBundle("https://relay-goerli.flashbots.net", bundle);
            require(
                // this hex is '{"id":1,"result"'
                // close-enough way to check for successful sendBundle call
                bytes16(bundleRes) == 0x7b226964223a312c22726573756c7422,
                "bundle failed"
            );

        // update confidential store's last ran block
        Suave.confidentialStore(_lastBlockProcessedRecord, KEY_LAST_BLOCK_PROCESSED, abi.encode(currentBlock)); // todo might need packed

        abi.encodeWithSelector(this.callbackRunAuction.selector, nextTxnIndexToInclude + includedTransactionCount);
    }

    function callbackRunAuction(uint256 nextTxnIndexToInclude_) external {
        nextTxnIndexToInclude = nextTxnIndexToInclude_;
    }

    function _findAuctionWinner(uint256 blockNum) internal returns (Bid memory, uint256) {
        // filter through bids for last auction
        Suave.DataId[] storage bids = _blockBids[blockNum];
        
        uint256 bestPrice = 0;
        uint256 secondPrice;
        Bid memory bestBid;

        for(uint i = 0; i < bids.length; i++) {
            Bid memory bid = abi.decode(Suave.confidentialRetrieve(bids[i], bidNamespace), (Bid));
            // check if bid passes simulation checks, if so, consider as valid bid
            bool passed = _simulateBid(bid);
            if(passed) {
                if(bid.payment > bestPrice) {
                    secondPrice = bestPrice;
                    bestPrice = bid.payment;
                    bestBid = bid;
                } else if (bid.payment > secondPrice) {
                    secondPrice = bid.payment;
                }
            }
        }
        if(secondPrice == 0) {
            // TODO: don't do this
            secondPrice = bestPrice;
        }

        return (bestBid, secondPrice);
    }

    function _simulateBid(Bid memory bid) internal returns (bool) {
        // check that bidder has enough funds to cover
        bytes memory depositResult = Suave.ethcall(targetDepositContract, abi.encodeWithSignature("balanceOf(address)", abi.encode(bid.bidder)));
        uint256 deposit = abi.decode(depositResult, (uint256));
        if(deposit < bid.payment) return false;

        // check that the withdraw and swap txns succeed
        string memory sessionId = string(bid.swapTxn);
        
        // (1) simulate pulling payments
        bytes memory paymentTxn = _createPostAuctionTransaction(bid, true);
        Suave.SimulateTransactionResult memory simRes = Suave.simulateTransaction(sessionId, paymentTxn);
        if(simRes.success = false) return false; // payment txn reverted

        // check for success log
        bool foundPaymentSuccessLog;
        for(uint i = 0; i < simRes.logs.length; ++i) {
            Suave.SimulatedLog memory log = simRes.logs[i];
            if(log.addr == targetAMM) {
                for(uint j = 0; j < log.topics.length; j++) {
                    if(log.topics[j] == keccak256(abi.encode("SuccessfulPayment"))) {
                        foundPaymentSuccessLog = true;
                        break;
                    }
                }
            }
            if(foundPaymentSuccessLog) break;
        }
        if(!foundPaymentSuccessLog) return false;

        // (2) simluate swap txn
        simRes = Suave.simulateTransaction(sessionId, paymentTxn);
        if(simRes.success = false) return false; // payment txn reverted

        bool foundSwapSuccessLog;
        for(uint i = 0; i < simRes.logs.length; ++i) {
            Suave.SimulatedLog memory log = simRes.logs[i];
            if(log.addr == targetAMM) {                for(uint j = 0; j < log.topics.length; j++) {
                    if(log.topics[j] == keccak256(abi.encode("AuctionSucceeded"))) {
                        foundSwapSuccessLog = true;
                        break;
                    }
                }
            }
            if(foundSwapSuccessLog) break;
        }
        if(!foundSwapSuccessLog) return false;

        // bid's execution is valid 
        return true;
    }

    function _createPostAuctionTransaction(Bid memory bid, bool auctionHasWinner) internal returns (bytes memory) {
        // create tx to sign with private key
        bytes memory targetCall = abi.encodeWithSignature(
            "postAuctionResults(address,uint256,uint256,bool,uint8,bytes32,bytes32)",
            bid.bidder,
            bid.blockNumber,
            bid.payment,
            auctionHasWinner,
            bid.v,
            bid.r,
            bid.s
        );

        // create transaction
        Transactions.EIP155Request memory txn = Transactions.EIP155Request({
            to: targetAMM,
            gas: gasNeededPostAuctionResults,
            gasPrice: gasPrice,
            value: 0,
            nonce: signingKeyNonce,
            data: targetCall,
            chainId: chainId
        });

        // encode transaction 
        bytes memory rlpTxn = Transactions.encodeRLP(txn);

        // grab signing key
        uint256 signingKey = uint256(
            bytes32(Suave.confidentialRetrieve(_signingKeyRecord, KEY_PRIVATE_KEY))
        );

         // sign transaction with key
        bytes memory signedTxn = Suave.signEthTransaction(
            rlpTxn,
            LibString.toMinimalHexString(chainId),
            LibString.toHexStringNoPrefix(signingKey)
        );

        return signedTxn;
    }

    // TODO: if there is time   
    function updateBid() external returns (bytes memory) {}
    function callBackUpdateBid() external {}

    function _getLastL1BlockTime() internal returns (uint256) {
        
        return 0;
    }

    function _getLastL1Block() internal returns (uint256) {
        string memory httpURL = string(Suave.confidentialRetrieve(_ethGoerliUrlRecord, KEY_URL));

        Suave.HttpRequest memory request;
        request.method = "POST";
        request.body = '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}';
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        request.withFlashbotsSignature = false;
        request.url = httpURL;

        string memory result = string(Suave.doHTTPRequest(request));
        console.logString(result);

        // TODO: how tf to parse this result? 

        // parse into block object
        
 
    }

    function _getLastL1BlockNumber() internal returns (uint256) {
        return 0;
    }

    function _getLastL1BlockInfo() internal returns (uint256, uint256) {
        

        return (0,0);
    }

    /**
     * @notice Sets the signing key in Suave's confidential storage
     * @return bytes Encoded data for updating the key callback
     */
    function setSigningKey(uint256 keyNonce) external onlyOwner returns (bytes memory) {
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
                bid.id,
                keyNonce
            );
    }

    /**
     * @notice Callback function to update the signing key record
     * @dev To be called as a Confidential Compute Callback.
     * @param signingKeyBid_ The new signing key record ID
     */ 
    function callbackSetSigningKey(
        Suave.DataId signingKeyBid_
    ) external {
        _signingKeyRecord = signingKeyBid_;
        emit UpdateKey(_signingKeyRecord);
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
            contractNamespace
        );
        Suave.confidentialStore(bid.id, KEY_URL, keyData);

        return
            abi.encodeWithSelector(
                this.callbackSetGoerliUrl.selector, bid.id
            );
    }

    /**
     * @notice Callback function to update the Goerli network URL record
     * @dev To be called as a Confidential Compute Callback.
     * @param goerliKeyId The record ID for the Goerli URL
     */
    function callbackSetGoerliUrl(
        Suave.DataId goerliKeyId
    ) external {
        _ethGoerliUrlRecord = goerliKeyId;
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
        Suave.confidentialStore(bid.id, KEY_LAST_BLOCK_PROCESSED, abi.encode(0));

        return
            abi.encodeWithSelector(
                this.callbackInitLastL1Block.selector, bid.id
            );
    }

    /**
     * @notice Callback function to init the last processed block data record 
     * @dev To be called as a Confidential Compute Request.
     * @param lastL1BlockKeyId The record ID for the last processed block
     */
    function callbackInitLastL1Block(
        Suave.DataId lastL1BlockKeyId 
    ) external {
        _lastBlockProcessedRecord = lastL1BlockKeyId;
    }
}
