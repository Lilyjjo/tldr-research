// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Transactions} from "suave-std/Transactions.sol";

import {SigUtils} from "./utils/EIP712Helpers.sol";

import {TestingBase} from "./TestingBase.s.sol";
import {UniswapBase} from "./UniswapBase.s.sol";

/**
 * @title Interactions for Poke<>PokeRelayer Contracts
 * @author lilyjjo
 * @dev Commands for interacting with Poked and PokeRelayer on Suave/Sepolia
 * @dev Need to fill out environment variables in .env
 * @dev Can toggle between Rigil and local devnet with USE_RIGIL env var
 */
contract BlockBuilding is TestingBase {
    /**
     * @notice Helper function for signing pokes.
     */
    function _createWithdrawEIP712(
        address user,
        uint256 userPk,
        uint256 blockNumber,
        uint256 payment
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        // setup SigUtils
        bytes32 TYPEHASH = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

        bytes32 WITHDRAW_TYPEHASH = keccak256(
            "withdrawBid(address bidder,uint256 blockNumber,uint256 amount)"
        );

        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                TYPEHASH,
                keccak256(bytes("AuctionDeposits")),
                keccak256(bytes("v1")),
                5,
                SUAPP_AMM_DEPLOYED
            )
        );
        SigUtils sigUtils = new SigUtils(DOMAIN_SEPARATOR, WITHDRAW_TYPEHASH);
        bytes32 digest = sigUtils.getTypedDataHash(user, blockNumber, payment);
        (v, r, s) = vm.sign(userPk, digest);
    }

    function _signTransaction(
        address to,
        uint256 gas,
        uint256 gasPrice,
        uint256 value,
        uint256 nonce,
        bytes memory targetCall,
        uint256 chainId,
        uint256 privateKey
    ) internal pure returns (bytes memory) {
        // create transaction
        uint8 v;
        bytes32 r;
        bytes32 s;
        {
            // scoping for stack too deep
            Transactions.EIP155Request memory txn = Transactions.EIP155Request({
                to: to,
                gas: gas,
                gasPrice: gasPrice,
                value: value,
                nonce: nonce,
                data: targetCall,
                chainId: chainId
            });

            // TODO: this might be wrong somehow
            // encode transaction
            bytes memory rlpTxn = Transactions.encodeRLP(txn);
            bytes32 digest = keccak256(rlpTxn);
            (v, r, s) = vm.sign(privateKey, digest);
        }

        // encode signed transaction
        Transactions.EIP155 memory signedTxn = Transactions.EIP155({
            to: to,
            gas: gas,
            gasPrice: gasPrice,
            value: value,
            nonce: nonce,
            data: targetCall,
            chainId: chainId,
            v: v,
            r: r,
            s: s
        });

        return Transactions.encodeRLP(signedTxn);
    }
}
