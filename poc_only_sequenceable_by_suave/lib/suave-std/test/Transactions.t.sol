// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Transactions.sol";

contract TestTransactions is Test {
    using Transactions for *;

    function testEIP155TransactionRLPEncoding() public {
        Transactions.EIP155 memory txnWithToAddress = Transactions.EIP155({
            to: address(0x095E7BAea6a6c7c4c2DfeB977eFac326aF552d87),
            gas: 50000,
            gasPrice: 10,
            value: 10,
            nonce: 0,
            data: bytes(""),
            chainId: 0,
            v: abi.encodePacked(hex"1b"),
            r: abi.encodePacked(hex"9bea4c4daac7c7c52e093e6a4c35dbbcf8856f1af7b059ba20253e70848d094f"),
            s: abi.encodePacked(hex"8a8fae537ce25ed8cb5af9adac3f141af69bd515bd2ba031522df09b97dd72b1")
        });

        bytes memory expected = abi.encodePacked(
            hex"f85f800a82c35094095e7baea6a6c7c4c2dfeb977efac326af552d870a801ba09bea4c4daac7c7c52e093e6a4c35dbbcf8856f1af7b059ba20253e70848d094fa08a8fae537ce25ed8cb5af9adac3f141af69bd515bd2ba031522df09b97dd72b1"
        );
        _testEIP155Transaction(txnWithToAddress, expected);

        Transactions.EIP155 memory txnWithoutToAddress = Transactions.EIP155({
            to: address(0),
            gas: 50000,
            gasPrice: 10,
            value: 10,
            nonce: 1,
            data: abi.encodePacked(hex"02"),
            chainId: 0,
            v: abi.encodePacked(hex"1b"),
            r: abi.encodePacked(hex"754a33a9c37cfcf61cd61939fd93f5fe194b7d1ee6ef07490e8c880f3bd0d87d"),
            s: abi.encodePacked(hex"715bd50fa2c24e2ce0ea595025a44a39ac238558882f9f07dd885ddc51839419")
        });

        expected = abi.encodePacked(
            hex"f84b010a82c350800a021ba0754a33a9c37cfcf61cd61939fd93f5fe194b7d1ee6ef07490e8c880f3bd0d87da0715bd50fa2c24e2ce0ea595025a44a39ac238558882f9f07dd885ddc51839419"
        );
        _testEIP155Transaction(txnWithoutToAddress, expected);
    }

    function _testEIP155Transaction(Transactions.EIP155 memory legacyTxn, bytes memory expectedRlp) public {
        bytes memory rlp = Transactions.encodeRLP(legacyTxn);
        assertEq0(rlp, expectedRlp);

        Transactions.EIP155 memory legacyTxn1 = Transactions.decodeRLP_EIP155(rlp);

        // re-encode to validate that the decoding was correct
        bytes memory rlp1 = Transactions.encodeRLP(legacyTxn1);
        assertEq0(rlp1, expectedRlp);
    }
}
