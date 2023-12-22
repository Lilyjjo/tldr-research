// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title Proof of Concept for an application with functions restricted to a specific SUAPP.
 * @notice This contract is designed to count 'pokes' from users, which can only be sequence through a specified SUAPP.
 * @author @lilyjjo
 */
contract OnlySUAPPCounter is EIP712 {
    // Keeps track of the number of pokes per user.
    mapping(address => uint256) public userPokes;
    // Nonce for each user to ensure unique transactions.
    mapping(address => uint256) public nonces;

    // SUAPP address allowed to sequence pokes.
    address public suapp;
    // Owner of the contract.
    address public owner;

    // Hash of the poke type for EIP-712 compliance.
    bytes32 private constant POKE_TYPEHASH =
        keccak256(
            "Poke(address user,address permittedSuapp,uint256 deadline,uint256 nonce)"
        );

    // Event emitted when the owner is changed.
    event OwnerChanged(address indexed _oldOwner, address indexed _newOwner);
    // Event emitted when the SUAPP address is changed.
    event SuappChanged(address indexed _oldSuapp, address indexed _newSuapp);
    // Event emitted when a user is poked.
    event Poked(address indexed _user, uint256 pokeCumulation);

    // Errors for various contract exceptions.
    error OnlyOwner();
    error OnlySuapp();
    error WrongSuapp();
    error PokeExpired();
    error WrongSigner();
    error ZeroAddress();

    /**
     * @dev Ensures the caller is the specified SUAPP.
     */
    modifier onlySuapp() {
        if (msg.sender != suapp) revert OnlySuapp();
        _;
    }

    /**
     * @dev Ensures the caller is the owner of the contract.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    /**
     * @dev Initializes the contract setting the initial SUAPP and the owner to the sender.
     * @param _suapp Address of the permitted SUAPP.
     */
    constructor(address _suapp) EIP712("SuappCounter", "1") {
        suapp = _suapp;
        owner = msg.sender;
    }

    /**
     * @dev Internal function to increment the poke count of a user.
     * @param user The address of the user to increment the poke count for.
     */
    function _incrementPoke(address user) internal {
        userPokes[user]++;
    }

    /**
     * @notice Allows the SUAPP to 'poke' a user, incrementing their poke count, if the correct signature is provided.
     * @dev Verifies the signature and increments poke count for the user. Reverts if conditions are not met.
     * @param user The user to be poked.
     * @param permittedSuapp The SUAPP permitted to initiate the poke.
     * @param deadline The deadline for the poke to be valid.
     * @param v, r, s Signature components.
     */
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

    /**
     * @notice Allows the owner to change the contract's owner.
     * @dev Changes the owner of the contract. Emits an OwnerChanged event.
     * @param newOwner The address of the new owner.
     */
    function setOwner(address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnerChanged(oldOwner, owner);
    }

    /**
     * @notice Allows the owner to change the SUAPP address.
     * @dev Changes the SUAPP address of the contract. Emits a SuappChanged event.
     * @param newSUAPP The address of the new SUAPP.
     */
    function setSuapp(address newSUAPP) public onlyOwner {
        if (newSUAPP == address(0)) revert ZeroAddress();
        address oldSuapp = suapp;
        suapp = newSUAPP;
        emit SuappChanged(oldSuapp, suapp);
    }
}
