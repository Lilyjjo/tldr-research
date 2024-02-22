// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SigUtils {
    bytes32 immutable DOMAIN_SEPARATOR;
    bytes32 immutable WITHDRAW_TYPEHASH;

    constructor(bytes32 _DOMAIN_SEPARATOR, bytes32 _WITHDRAW_TYPEHASH) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
        WITHDRAW_TYPEHASH = _WITHDRAW_TYPEHASH;
    }

    // computes the hash of a permit
    function getStructHash(
        address bidder,
        uint256 blocknumber,
        uint256 payment
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(WITHDRAW_TYPEHASH, bidder, blocknumber, payment)
            );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(
        address bidder,
        uint256 blocknumber,
        uint256 payment
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    getStructHash(bidder, blocknumber, payment)
                )
            );
    }
}
