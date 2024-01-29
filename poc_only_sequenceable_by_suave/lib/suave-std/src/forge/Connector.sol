// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

interface connectorVM {
    function ffi(string[] calldata commandInput) external view returns (bytes memory result);
}

contract Connector {
    connectorVM constant vm = connectorVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function forgeIt(bytes memory addr, bytes memory data) internal view returns (bytes memory) {
        string memory addrHex = iToHex(addr);
        string memory dataHex = iToHex(data);

        string[] memory inputs = new string[](4);
        inputs[0] = "suave-geth";
        inputs[1] = "forge";
        inputs[2] = addrHex;
        inputs[3] = dataHex;

        bytes memory res = vm.ffi(inputs);
        return res;
    }

    function iToHex(bytes memory buffer) public pure returns (string memory) {
        bytes memory converted = new bytes(buffer.length * 2);

        bytes memory _base = "0123456789abcdef";

        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }

        return string(abi.encodePacked("0x", converted));
    }

    fallback() external {
        bytes memory msgdata = forgeIt(abi.encodePacked(address(this)), msg.data);

        assembly {
            let location := msgdata
            let length := mload(msgdata)
            return(add(location, 0x20), length)
        }
    }
}
