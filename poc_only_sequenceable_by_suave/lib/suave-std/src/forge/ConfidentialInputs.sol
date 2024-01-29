// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

contract ConfidentialInputsWrapper {
    bytes confidentialInputs;

    function setConfidentialInputs(bytes memory _confidentialInputs) public {
        confidentialInputs = _confidentialInputs;
    }

    function resetConfidentialInputs() public {
        confidentialInputs = "";
    }

    fallback() external {
        // copy bytes from storage to memory
        bytes memory msgdata = new bytes(confidentialInputs.length);
        for (uint256 i = 0; i < confidentialInputs.length; i++) {
            msgdata[i] = confidentialInputs[i];
        }

        assembly {
            let location := msgdata
            let length := mload(msgdata)
            return(add(location, 0x20), length)
        }
    }
}
