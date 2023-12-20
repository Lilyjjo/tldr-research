// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract OnlySUAPPCounter is EIP712 {
    mapping(address => uint256) public userPokes;
    mapping(address => uint256) private _nonces;

    address suapp;
    address owner;

    bytes32 private constant POKE_TYPEHASH =
        keccak256(
            "Poke(address user,address permittedSuapp,uint256 deadline,uint256 nonce)"
        );

    event OwnerChanged(address indexed _oldOwner, address indexed _newOwner);
    event SuappChanged(address indexed _oldSuapp, address indexed _newSuapp);
    event Poked(address indexed _user, uint256 pokeCumulation);

    modifier only_suapp() {
        require(msg.sender == suapp, "Only SUAPP");
        _;
    }

    modifier only_owner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address _suapp) EIP712("SuappCounter", "1") {
        suapp = _suapp;
        owner = msg.sender;
    }

    function _incrementPoke(address user) internal {
        userPokes[user]++;
    }

    function poke(
        address user,
        address permittedSuapp,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual only_suapp {
        require(permittedSuapp == suapp, "Wrong SUAPP");
        require(block.timestamp > deadline, "Poke expired");

        bytes32 structHash = keccak256(
            abi.encode(user, permittedSuapp, deadline, _nonces[user]++)
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == user, "Signer != User");

        _incrementPoke(user);
    }

    function setOwner(address newOwner) public only_owner {
        require(newOwner != address(0), "Zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnerChanged(oldOwner, owner);
    }

    function setSUAPP(address newSUAPP) public only_owner {
        require(newSUAPP != address(0), "Zero address");
        address oldSuapp = suapp;
        suapp = newSUAPP;
        emit SuappChanged(oldSuapp, suapp);
    }
}
