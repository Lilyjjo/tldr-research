// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {RLPEncoder} from "./RLPEncoder.sol";
import "forge-std/console.sol";

/**
 * @title CCRForgeUtil
 * @author @lilyjjo
 * @dev A utility contract for creating and sending Confidential Compute Requests in a Forge environment.
 */
contract CCRForgeUtil is Script {
    bytes1 constant CONFIDENTIAL_COMPUTE_RECORD_TYPE = 0x42;
    bytes1 constant CONFIDENTIAL_COMPUTE_REQUEST_TYPE = 0x43;

    /**
     * @dev Struct to hold the data of a Confidential Compute Record.
     */
    struct ConfidentialComputeRecordData {
        uint64 nonce;
        address to;
        uint256 gas;
        uint256 gasPrice;
        uint256 value;
        bytes data;
        address executionNode;
        uint256 chainId;
    }

    /**
     * @dev Struct to represent a Confidential Compute Request.
     */
    struct ConfidentialComputeRequest {
        ConfidentialComputeRecordData ccrD;
        bytes confidentialInputs;
        bytes32 confidentialInputsHash;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @dev Create and send a Confidential Compute Record (CCR) to the specified chain.
     * @param signingPrivateKey Private key for signing the CCR.
     * @param confidentialInputs Confidential inputs for use in the transaction.
     * @param targetCall Which function+args to call on 'to'.
     * @param nonce Nonce of the signingPrivateKey.
     * @param to Target address on Suave chain.
     * @param gas Gas limit for the transaction.
     * @param gasPrice Gas price.
     * @param value Value in wei to send with the transaction.
     * @param executionNode Address of the execution node.
     * @param chainId ID of the blockchain.
     */
    function createAndSendCCR(
        uint256 signingPrivateKey,
        bytes memory confidentialInputs,
        bytes memory targetCall,
        uint64 nonce,
        address to,
        uint256 gas,
        uint256 gasPrice,
        uint256 value,
        address executionNode,
        uint256 chainId
    ) public {
        CCRForgeUtil.ConfidentialComputeRecordData memory ccrD;
        {
            ccrD = CCRForgeUtil.ConfidentialComputeRecordData({
                nonce: nonce,
                to: to,
                gas: gas,
                gasPrice: gasPrice,
                value: value,
                data: targetCall,
                executionNode: address(executionNode),
                chainId: chainId
            });
        }

        bytes memory ccr = ccrdToRLPEncodedCCR(
            ccrD,
            confidentialInputs,
            signingPrivateKey
        );
        sendCCR(ccr);
    }

    /**
     * @dev Send the encoded Confidential Compute Request to the environment's RPC.
     * @notice This function will cause scripts to revert even when the CCR is successfully sent.
     * @param rlpCCR The RLP encoded CCR data.
     */
    function sendCCR(bytes memory rlpCCR) public {
        string memory params = string(
            abi.encodePacked('["', vm.toString(rlpCCR), '"]')
        );
        // note: will revert even on successful calls
        vm.rpc("eth_sendRawTransaction", params);
    }

    /**
     * @dev Convert a ConfidentialComputeRecordData to RLP encoded CCR.
     * @param ccrD The ConfidentialComputeRecordData.
     * @param confidentialInputs Confidential inputs for the CCR.
     * @param signingPrivateKey Private key for signing the CCR.
     * @return rlpEncodedCCR RLP encoded CCR, ready for broadcast.
     */
    function ccrdToRLPEncodedCCR(
        ConfidentialComputeRecordData memory ccrD,
        bytes memory confidentialInputs,
        uint256 signingPrivateKey
    ) public pure returns (bytes memory rlpEncodedCCR) {
        ConfidentialComputeRequest memory ccr = createCCR(
            ccrD,
            confidentialInputs,
            signingPrivateKey
        );
        return _rlpEncodeCCR(ccr);
    }

    /**
     * @dev Create a Confidential Compute Request.
     * @param ccrD The ConfidentialComputeRecordData.
     * @param confidentialInputs Confidential inputs for the CCR.
     * @param signingPrivateKey Private key for signing the CCR.
     * @return ccr ConfidentialComputeRequest.
     */
    function createCCR(
        ConfidentialComputeRecordData memory ccrD,
        bytes memory confidentialInputs,
        uint256 signingPrivateKey
    ) public pure returns (ConfidentialComputeRequest memory ccr) {
        ccr.ccrD = ccrD;
        ccr.confidentialInputs = confidentialInputs;
        ccr.confidentialInputsHash = keccak256(confidentialInputs);

        bytes memory rlpEncodedCCRD = _rlpEncodeCCRD(
            ccrD,
            ccr.confidentialInputsHash
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signingPrivateKey,
            keccak256(rlpEncodedCCRD)
        );
        ccr.v = v == 27 ? 0 : 1;
        ccr.r = r;
        ccr.s = s;
    }

    /**
     * @dev Internal function to RLP encode a ConfidentialComputeRecordData.
     * @param ccrD The ConfidentialComputeRecordData to encode.
     * @param confidentialInputHash Hash of the confidential inputs.
     * @return rlpEncodedCCRD The RLP encoded ConfidentialComputeRecordData.
     */
    function _rlpEncodeCCRD(
        ConfidentialComputeRecordData memory ccrD,
        bytes32 confidentialInputHash
    ) internal pure returns (bytes memory rlpEncodedCCRD) {
        bytes[] memory rlpEncodings = new bytes[](8);

        rlpEncodings[0] = RLPEncoder._rlpEncodeAddress(ccrD.executionNode);
        rlpEncodings[1] = RLPEncoder._rlpEncodeBytes(
            abi.encode(confidentialInputHash)
        );
        rlpEncodings[2] = RLPEncoder._rlpEncodeUint(ccrD.nonce);
        rlpEncodings[3] = RLPEncoder._rlpEncodeUint(ccrD.gasPrice);
        rlpEncodings[4] = RLPEncoder._rlpEncodeUint(ccrD.gas);
        rlpEncodings[5] = RLPEncoder._rlpEncodeAddress(ccrD.to);
        rlpEncodings[6] = RLPEncoder._rlpEncodeUint(ccrD.value);
        rlpEncodings[7] = RLPEncoder._rlpEncodeBytes(ccrD.data);

        bytes memory rlpEncodedData = RLPEncoder._rlpEncodeList(rlpEncodings);

        rlpEncodedCCRD = new bytes(1 + rlpEncodedData.length);
        rlpEncodedCCRD[0] = CONFIDENTIAL_COMPUTE_RECORD_TYPE;

        for (uint i = 0; i < rlpEncodedData.length; ++i) {
            rlpEncodedCCRD[i + 1] = rlpEncodedData[i];
        }
    }

    /**
     * @dev Internal function to RLP encode a ConfidentialComputeRequest.
     * @dev The results of this function are ready to be broadcasted.
     * @param ccr The ConfidentialComputeRequest to encode.
     * @return rlpEncodedCCRCI The RLP encoded ConfidentialComputeRequest and Confidential Inputs.
     */
    function _rlpEncodeCCR(
        ConfidentialComputeRequest memory ccr
    ) internal pure returns (bytes memory rlpEncodedCCRCI) {
        // step 1: encode the CCR data
        bytes[] memory rlpEncodingsCCR = new bytes[](12);
        rlpEncodingsCCR[0] = RLPEncoder._rlpEncodeUint(ccr.ccrD.nonce);
        rlpEncodingsCCR[1] = RLPEncoder._rlpEncodeUint(ccr.ccrD.gasPrice);
        rlpEncodingsCCR[2] = RLPEncoder._rlpEncodeUint(ccr.ccrD.gas);
        rlpEncodingsCCR[3] = RLPEncoder._rlpEncodeAddress(ccr.ccrD.to);
        rlpEncodingsCCR[4] = RLPEncoder._rlpEncodeUint(ccr.ccrD.value);
        rlpEncodingsCCR[5] = RLPEncoder._rlpEncodeBytes(ccr.ccrD.data);
        rlpEncodingsCCR[6] = RLPEncoder._rlpEncodeAddress(
            ccr.ccrD.executionNode
        );
        rlpEncodingsCCR[7] = RLPEncoder._rlpEncodeBytes(
            abi.encode(ccr.confidentialInputsHash)
        );
        rlpEncodingsCCR[8] = RLPEncoder._rlpEncodeUint(
            uint256(ccr.ccrD.chainId)
        );
        rlpEncodingsCCR[9] = RLPEncoder._rlpEncodeUint(ccr.v);
        rlpEncodingsCCR[10] = RLPEncoder._rlpEncodeBytes(abi.encode(ccr.r));
        rlpEncodingsCCR[11] = RLPEncoder._rlpEncodeBytes(abi.encode(ccr.s));

        bytes memory rlpEncodedCCR = RLPEncoder._rlpEncodeList(rlpEncodingsCCR);

        // step 2: encode the confidential inputs data and put into list with ccr
        bytes[] memory rlpEncodingsCCRCI = new bytes[](2);
        rlpEncodingsCCRCI[0] = rlpEncodedCCR;
        rlpEncodingsCCRCI[1] = RLPEncoder._rlpEncodeBytes(
            ccr.confidentialInputs
        );

        bytes memory rlpEncodedData = RLPEncoder._rlpEncodeList(
            rlpEncodingsCCRCI
        );

        // step 3: append the confidential compute request transaction id
        rlpEncodedCCRCI = new bytes(1 + rlpEncodedData.length);
        rlpEncodedCCRCI[0] = CONFIDENTIAL_COMPUTE_REQUEST_TYPE;

        for (uint i = 0; i < rlpEncodedData.length; ++i) {
            rlpEncodedCCRCI[i + 1] = rlpEncodedData[i];
        }
    }
}
