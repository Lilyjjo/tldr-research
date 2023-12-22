// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    // keccak256("Poke(address user,address permittedSuapp,uint256 deadline,uint256 nonce)")
    bytes32 public constant POKE_TYPEHASH =
        0x55520b7dd6f5df16c1f127cbc597b5edac9c3b9ddd62140e3daa73d59795080c;

    struct Poke {
        address user;
        address permittedSuapp;
        uint256 deadline;
        uint256 nonce;
    }

    // computes the hash of a permit
    function getStructHash(Poke memory _poke) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    POKE_TYPEHASH,
                    _poke.user,
                    _poke.permittedSuapp,
                    _poke.deadline,
                    _poke.nonce
                )
            );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(Poke memory _poke) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    getStructHash(_poke)
                )
            );
    }
}
