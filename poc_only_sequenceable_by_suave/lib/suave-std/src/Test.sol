// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "./forge/Registry.sol";
import "./suavelib/Suave.sol";
import "forge-std/Test.sol";

interface ConfidentialInputsWrapperI {
    function setConfidentialInputs(bytes memory) external;
    function resetConfidentialInputs() external;
}

contract SuaveEnabled is Test {
    ConfidentialInputsWrapperI constant confInputsWrapper = ConfidentialInputsWrapperI(Suave.CONFIDENTIAL_INPUTS);

    function setUp() public {
        string[] memory inputs = new string[](3);
        inputs[0] = "suave-geth";
        inputs[1] = "forge";
        inputs[2] = "status";

        try vm.ffi(inputs) returns (bytes memory response) {
            // the status call of the `suave-geth forge` command fails with the 'not-ok' prefix
            // which is '6e6f742d6f6b' in hex
            if (isPrefix(hex"6e6f742d6f6b", response)) {
                revert("Local Suave node not detected running");
            }
        } catch (bytes memory reason) {
            revert(detectErrorMessage(reason));
        }

        Registry.enable();

        confInputsWrapper.resetConfidentialInputs();
    }

    function setConfidentialInputs(bytes memory data) internal {
        confInputsWrapper.setConfidentialInputs(data);
    }

    function detectErrorMessage(bytes memory reason) internal pure returns (string memory) {
        // Errors from cheatcodes are reported as 'CheatcodeError(string)' events
        // 'eeaa9e6f' is the signature of the event
        if (!isPrefix(hex"eeaa9e6f", reason)) {
            return string(reason);
        }

        // retrieve the body of the event by removing the signature
        bytes memory eventBody = new bytes(reason.length - 4);
        for (uint256 i = 4; i < reason.length; i++) {
            eventBody[i - 4] = reason[i];
        }

        // decode event as 'tuple(bytes message)' since it is equivalent to tuple(string)
        (bytes memory message) = abi.decode(eventBody, (bytes));

        // the prefix is 'FFI is disabled' in hex
        if (isPrefix(hex"4646492069732064697361626c6564", message)) {
            return "Suave <> Forge integration requires the --ffi flag to be enabled";
        }

        // the prefix is 'failed to execute command' in hex
        if (isPrefix(hex"6661696c656420746f206578656375746520636f6d6d616e64", message)) {
            return "Forge cannot locate the 'suave' binary. Is it installed in $PATH?";
        }

        return string(message);
    }

    function isPrefix(bytes memory prefix, bytes memory data) internal pure returns (bool) {
        if (prefix.length > data.length) {
            return false;
        }
        for (uint256 i = 0; i < prefix.length; i++) {
            if (prefix[i] != data[i]) {
                return false;
            }
        }
        return true;
    }
}
