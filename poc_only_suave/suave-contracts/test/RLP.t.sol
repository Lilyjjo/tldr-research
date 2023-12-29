// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {RLPEncoderWrapper} from "./wrappers/RLPEncoderWrapper.sol";
import "forge-std/console.sol";

contract RLPEncoderTest is Test {
    RLPEncoderWrapper encoder;

    function setUp() public {
        encoder = new RLPEncoderWrapper();
    }

    function test_EncodeAddress() public {
        encoder.rlpEncodeAddress(address(1));
    }

    function test_EncodeNumber1() public {
        encoder.rlpEncodeUint(1);
    }

    function test_EncodeNumber128() public {
        encoder.rlpEncodeUint(128);
    }

    function test_EncodeNumber129() public {
        encoder.rlpEncodeUint(129);
    }

    function test_EncodeNumber65535() public {
        encoder.rlpEncodeUint(65535);
    }

    function test_EncodeNumber65536() public {
        encoder.rlpEncodeUint(65536);
    }

    function test_EncodeNumberHalfMax() public {
        encoder.rlpEncodeUint(type(uint256).max / 2);
    }

    function test_EncodeNumberMax() public {
        encoder.rlpEncodeUint(type(uint256).max);
    }

    function test_EncodeLargeString() public {
        uint256 length = 56;
        bytes memory test = new bytes(length);
        for (uint i = 0; i < test.length; ++i) {
            test[i] = 0xaa;
        }
        test[length - 1] = 0xee;
        test[0] = 0xbb;
        console.log("data length: %d", test.length);
        console.logBytes(test);
        console.log("post rlp:");
        console.logBytes(encoder.rlpEncodeBytes(test));
    }

    function test_EncodeList() public {
        bytes[] memory data = new bytes[](3);
        console.log("he");
        data[0] = encoder.rlpEncodeUint(1);
        data[1] = encoder.rlpEncodeUint(88);
        //data[1] = encoder.rlpEncodeBytes(new bytes(0xcc));
        data[2] = encoder.rlpEncodeUint(1);
        console.log("list:");
        console.logBytes(encoder.rlpEncodeList(data));
    }
}
