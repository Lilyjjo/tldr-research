// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title RLP Encoder for Solidity Data Types
 * @author @lilyjjo
 * @notice Unaudited :)
 * @notice The specification can be found at: https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/
 */
library RLPEncoder {
    /**
     * @notice Finds the first least significant bit set in `x`.
     * @dev Uses bitwise operations to identify the position of the least significant bit.
     * @param x The value to find the least significant bit in.
     * @return r The position of the first least significant bit.
     * Taken from:  https://github.com/Vectorized/solady/blob/d457831578c0714d648ef19b599f9d7172113816/src/utils/LibBit.sol#L16
     */
    function fls(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            r := or(
                shl(8, iszero(x)),
                shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            )
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            r := or(r, shl(2, lt(0xf, shr(r, x))))
            r := or(r, byte(shr(r, x), hex"00000101020202020303030303030303"))
        }
    }

    /**
     * @notice Encodes a bytes array into RLP format.
     * @param data The bytes array to encode.
     * @return encoded The RLP encoded bytes array.
     */
    function _rlpEncodeBytes(
        bytes memory data
    ) internal pure returns (bytes memory encoded) {
        if (data.length == 1) {
            if (uint256(uint8(data[0])) < 128) {
                encoded = data;
            }
        }
        if (data.length < 56) {
            encoded = new bytes(1 + data.length);
            encoded[0] = bytes1(uint8(0x80) + uint8(data.length));
            for (uint i = 0; i < data.length; ++i) {
                encoded[i + 1] = data[i];
            }
        } else {
            uint256 bytesForLength = fls(data.length) / uint(8) + 1;
            encoded = new bytes(1 + bytesForLength + data.length);
            encoded[0] = bytes1(uint8(0xb7) + uint8(bytesForLength));
            // copy over length bytes
            for (uint i = 0; i < bytesForLength; ++i) {
                // bytes32 has leading zeros, non-zero bytes are on right side of array
                encoded[1 + bytesForLength - i - 1] = bytes32(data.length)[
                    31 - i
                ];
            }
            // copy over actual data
            for (uint i = 0; i < data.length; ++i) {
                encoded[i + 1 + bytesForLength] = data[i];
            }
        }
    }

    /**
     * @notice Encodes a list of bytes arrays into RLP format.
     * @dev All elements in data should already be in RLP format.
     * @param data An array of bytes arrays to be encoded.
     * @return encoded The RLP encoded list.
     */
    function _rlpEncodeList(
        bytes[] memory data
    ) internal pure returns (bytes memory encoded) {
        if (data.length == 0) {
            encoded = new bytes(1);
            encoded[0] = 0xc0;
        }

        uint256 combinedLength;
        for (uint i = 0; i < data.length; i++) {
            combinedLength += data[i].length;
        }

        if (combinedLength < 56) {
            encoded = new bytes(1 + combinedLength);
            encoded[0] = bytes1(uint8(0xc0) + uint8(combinedLength));
            uint k = 0;
            for (uint i = 0; i < data.length; ++i) {
                for (uint j = 0; j < data[i].length; ++j) {
                    encoded[k + 1] = data[i][j];
                    k++;
                }
            }
        } else {
            uint256 bytesForLength = fls(combinedLength) / uint(8) + 1;
            encoded = new bytes(1 + bytesForLength + combinedLength);
            encoded[0] = bytes1(uint8(0xf7) + uint8(bytesForLength));
            // copy over length bytes
            for (uint i = 0; i < bytesForLength; ++i) {
                // bytes32 has leading zeros, non-zero bytes are on right side of array
                encoded[1 + bytesForLength - i - 1] = bytes32(combinedLength)[
                    31 - i
                ];
            }
            // copy over actual data
            for (uint i = 0; i < data.length; ++i) {
                for (uint j = 0; j < data[i].length; ++j) {
                    encoded[1 + bytesForLength + i] = data[i][j];
                }
            }
        }
    }

    /**
     * @notice Encodes a uint256 into RLP format.
     * @dev Encodes uints using the smallest RLP byte array in big endian format.
     * @param data The uint256 value to encode.
     * @return encoded The RLP encoded uint256.
     */
    function _rlpEncodeUint(
        uint256 data
    ) internal pure returns (bytes memory encoded) {
        // rlp uints are encoded using the smallest byte array containing the
        // uint in big endian format with no leading zero bytes
        if (data < 56) {
            // bytes1 cast will grab first byte, need to shift over target byte
            encoded = new bytes(1);
            encoded[0] = bytes1(bytes32(data) << 248);
        } else {
            uint bytesForNumber = fls(data) / uint(8) + 1;
            bytes memory compactNumber = new bytes(bytesForNumber);
            for (uint i = 0; i < bytesForNumber; ++i) {
                // casting to bytes32 has leading zeros in number, need to just grab non-zero bytes
                compactNumber[bytesForNumber - i - 1] = bytes32(data)[31 - i];
            }
            encoded = _rlpEncodeBytes(compactNumber);
        }
    }

    /**
     * @notice Encodes an Ethereum address into RLP format.
     * @dev Converts an address to a 20-byte array and encodes it using RLP.
     * @param data The Ethereum address to encode.
     * @return encoded The RLP encoded address.
     */
    function _rlpEncodeAddress(
        address data
    ) internal pure returns (bytes memory encoded) {
        bytes memory data_ = new bytes(20);
        for (uint i = 0; i < 20; ++i) {
            data_[i] = bytes20(data)[i];
        }
        encoded = _rlpEncodeBytes(data_);
    }
}
