// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Suave} from "./SuaveLibrary/Suave.sol";

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

    // TODO: how to make sure callback is from us?
    function updateKeyCallback(
        Suave.BidId signingKeyBid_,
        uint256 keyNonce_
    ) external {
        signingKeyBid = signingKeyBid_;
        keyNonce = keyNonce_;
        emit UpdateKey(signingKeyBid);
    }

    // example is a function executed in a confidential request that includes
    // a callback that can modify the state.
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

    /*
    class Transaction1559Payload:
	chain_id: int = 0
	signer_nonce: int = 0
	max_priority_fee_per_gas: int = 0
	max_fee_per_gas: int = 0
	gas_limit: int = 0
	destination: int = 0
	amount: int = 0
	payload: bytes = bytes()
	access_list: List[Tuple[int, List[int]]] = field(default_factory=list)
	signature_y_parity: bool = False
	signature_r: int = 0
	signature_s: int = 0
    */
    function _rlpEncodeEIP1559Transaction(
        uint256 chainId_,
        uint256 keyNonce_,
        uint256 maxPriorityFeePerGas,
        uint256 maxFeePerGas,
        uint256 gasLimit,
        address destination,
        bytes memory payload
    ) internal returns (bytes memory txn) {
        // TODO
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
            gasPrice,
            gasPrice,
            gasNeeded,
            targetApp,
            targetCall
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
