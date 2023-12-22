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

    function test_PokeHappyPath() public {
        SigUtils.Poke memory poke = SigUtils.Poke({
            user: alice.addr,
            permittedSuapp: suapp,
            deadline: 1 days,
            nonce: 0
        });

        bytes32 digest = sigUtils.getTypedDataHash(poke);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice, digest);

        vm.prank(suapp);
        counter.poke(poke.user, poke.permittedSuapp, poke.deadline, v, r, s);

        assertEq(counter.userPokes(alice.addr), 1);
        assertEq(counter.nonces(alice.addr), 1);
    }
}
