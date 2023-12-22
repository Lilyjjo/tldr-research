// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {SigUtils} from "./utils/EIP712Helpers.t.sol";
import {OnlySUAPPCounter} from "../src/OnlySUAPPCounter.sol";
import "forge-std/console.sol";

contract OnlySUAPPCounterTest is Test {
    OnlySUAPPCounter counter;
    SigUtils sigUtils;
    address owner;
    address suapp;
    VmSafe.Wallet alice;
    VmSafe.Wallet bob;

    function setUp() public {
        // setup user addresses
        owner = address(1);
        suapp = address(2);
        alice = vm.createWallet("alice");
        bob = vm.createWallet("bob");

        // deploy contract
        vm.prank(owner);
        counter = new OnlySUAPPCounter(suapp);

        // setup eip712 sig utils
        bytes32 TYPE_HASH = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

        (
            ,
            string memory name,
            string memory version,
            uint256 chainId,
            ,
            ,

        ) = counter.eip712Domain();

        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                TYPE_HASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                address(counter)
            )
        );

        sigUtils = new SigUtils(DOMAIN_SEPARATOR);
    }

    function test_ChangeOwner() public {
        vm.expectRevert(OnlySUAPPCounter.OnlyOwner.selector);
        counter.setOwner(bob.addr);

        vm.prank(owner);
        vm.expectRevert(OnlySUAPPCounter.ZeroAddress.selector);
        counter.setOwner(address(0));

        vm.prank(owner);
        counter.setOwner(bob.addr);
        assertEq(counter.owner(), bob.addr);
    }

    function test_ChangeSuapp() public {
        vm.expectRevert(OnlySUAPPCounter.OnlyOwner.selector);
        counter.setSuapp(bob.addr);

        vm.prank(owner);
        vm.expectRevert(OnlySUAPPCounter.ZeroAddress.selector);
        counter.setSuapp(address(0));

        vm.prank(owner);
        counter.setSuapp(bob.addr);
        assertEq(counter.suapp(), bob.addr);
    }

    function _createPoke(
        address user,
        address permittedSuapp,
        uint256 deadline,
        uint256 nonce
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        SigUtils.Poke memory poke = SigUtils.Poke({
            user: user,
            permittedSuapp: permittedSuapp,
            deadline: deadline,
            nonce: nonce
        });

        bytes32 digest = sigUtils.getTypedDataHash(poke);

        return vm.sign(alice, digest);
    }

    function test_PokeHappyPath() public {
        address user = alice.addr;
        address permittedSuapp = suapp;
        uint256 deadline = block.timestamp;
        uint256 nonce = 0;

        (uint8 v, bytes32 r, bytes32 s) = _createPoke(
            user,
            permittedSuapp,
            deadline,
            nonce
        );

        vm.prank(suapp);
        counter.poke(user, permittedSuapp, deadline, v, r, s);

        assertEq(counter.userPokes(alice.addr), 1);
        assertEq(counter.nonces(alice.addr), 1);
    }

    function test_PokeExipred() public {
        address user = alice.addr;
        address permittedSuapp = suapp;
        uint256 deadline = block.timestamp - 1;
        uint256 nonce = 0;

        (uint8 v, bytes32 r, bytes32 s) = _createPoke(
            user,
            permittedSuapp,
            deadline,
            nonce
        );

        vm.expectRevert(OnlySUAPPCounter.PokeExpired.selector);
        vm.prank(suapp);
        counter.poke(user, permittedSuapp, deadline, v, r, s);
    }

    function test_PokeWrongSigner() public {
        address user = alice.addr;
        address permittedSuapp = suapp;
        uint256 deadline = block.timestamp;
        uint256 nonce = 0;

        (uint8 v, bytes32 r, bytes32 s) = _createPoke(
            user,
            permittedSuapp,
            deadline,
            nonce
        );

        vm.expectRevert(OnlySUAPPCounter.WrongSigner.selector);
        vm.prank(suapp);
        counter.poke(bob.addr, permittedSuapp, deadline, v, r, s);
    }

    function test_PokeWrongNonce() public {
        address user = alice.addr;
        address permittedSuapp = suapp;
        uint256 deadline = block.timestamp;
        uint256 nonce = 100;

        (uint8 v, bytes32 r, bytes32 s) = _createPoke(
            user,
            permittedSuapp,
            deadline,
            nonce
        );

        vm.expectRevert(OnlySUAPPCounter.WrongSigner.selector);
        vm.prank(suapp);
        counter.poke(alice.addr, permittedSuapp, deadline, v, r, s);
    }

    function test_PokeWrongSuapp() public {
        address user = alice.addr;
        address permittedSuapp = bob.addr;
        uint256 deadline = block.timestamp;
        uint256 nonce = 100;

        (uint8 v, bytes32 r, bytes32 s) = _createPoke(
            user,
            permittedSuapp,
            deadline,
            nonce
        );

        vm.expectRevert(OnlySUAPPCounter.WrongSuapp.selector);
        vm.prank(suapp);
        counter.poke(alice.addr, permittedSuapp, deadline, v, r, s);
    }
}
