// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract OnlySUAPPCounter is EIP712 {
    mapping(address => uint256) public userPokes;
    mapping(address => uint256) public nonces;

    address public suapp;
    address public owner;

    bytes32 private constant POKE_TYPEHASH =
        keccak256(
            "Poke(address user,address permittedSuapp,uint256 deadline,uint256 nonce)"
        );

    event OwnerChanged(address indexed _oldOwner, address indexed _newOwner);
    event SuappChanged(address indexed _oldSuapp, address indexed _newSuapp);
    event Poked(address indexed _user, uint256 pokeCumulation);

    error OnlyOwner();
    error OnlySuapp();
    error WrongSuapp();
    error PokeExpired();
    error WrongSigner();
    error ZeroAddress();

    modifier onlySuapp() {
        if (msg.sender != suapp) revert OnlySuapp();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
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
    ) public virtual onlySuapp {
        if (permittedSuapp != suapp) revert WrongSuapp();
        if (block.timestamp > deadline) revert PokeExpired();

        bytes32 structHash = keccak256(
            abi.encode(
                POKE_TYPEHASH,
                user,
                permittedSuapp,
                deadline,
                nonces[user]++
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != user) revert WrongSigner();

        _incrementPoke(user);
    }

    function setOwner(address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnerChanged(oldOwner, owner);
    }

    function setSuapp(address newSUAPP) public onlyOwner {
        if (newSUAPP == address(0)) revert ZeroAddress();
        address oldSuapp = suapp;
        suapp = newSUAPP;
        emit SuappChanged(oldSuapp, suapp);
    }
}
