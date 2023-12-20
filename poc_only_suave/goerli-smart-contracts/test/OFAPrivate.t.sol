// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {OnlySUAPPCounter} from "../src/OnlySUAPP.sol";

contract OnlySUAPPCounterTest is Test {
    OnlySUAPPCounter public counter;

    function setUp() public {}

    function test_Increment() public {}

    function testFuzz_SetNumber(uint256 x) public {}
}
