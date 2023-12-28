// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RLPEncoder} from "../../src/utils/RLPEncoder.sol";

/**
 * @title RLPEncoderWrapper
 * @notice Util contract for testing internal functions of RLPEncoderWrapper library.
 */
contract RLPEncoderWrapper {
    function rlpEncodeBytes(
        bytes memory data
    ) public view returns (bytes memory) {
        return RLPEncoder._rlpEncodeBytes(data);
    }

    function rlpEncodeUint(uint256 data) public view returns (bytes memory) {
        return RLPEncoder._rlpEncodeUint(data);
    }

    function rlpEncodeAddress(address data) public view returns (bytes memory) {
        return RLPEncoder._rlpEncodeAddress(data);
    }

    function rlpEncodeList(
        bytes[] memory data
    ) public view returns (bytes memory) {
        return RLPEncoder._rlpEncodeList(data);
    }
}
