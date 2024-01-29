# Suave-std

Suave Standard library (`suave-std`) is a collection of helpful contracts and libraries to build Suapps.

## Installation

To install with [Foundry](https://github.com/foundry-rs/foundry):

```bash
forge install flashbots/suave-std
```

## Libraries

### Transactions.sol

Helper library that defines types and encoding/decoding methods for the Ethereum transaction types.

#### Example usage

```solidity
import "suave-std/Transactions.sol";

contract Example {
    function example() {
        Transactions.Legacy memory legacyTxn0 = Transactions.Legacy({
            to: address(0x095E7BAea6a6c7c4c2DfeB977eFac326aF552d87),
            gas: 50000,
            gasPrice: 10,
            value: 10,
            ...
        });

        // Encode to RLP
        bytes memory rlp = Transactions.encodeRLP(legacyTxn0);

        // Decode from RLP
        Transactions.Legacy memory legacyTxn1 = Transactions.decodeRLP(rlp);
    }
}
```

### protocols/MevShare.sol

Helper library to send bundle requests with the Mev-Share protocol.

#### Example usage

```solidity
import "suave-std/protocols/MevShare.sol";

contract Example {
    function example() {
        Transactions.Legacy memory legacyTxn0 = Transactions.Legacy({});
        bytes memory rlp = Transactions.encodeRLP(legacyTxn0);

        MevShare.Bundle memory bundle;
        bundle.bodies = new bytes[](1);
        bundle.bodies[0] = rlp;
        // ...

        MevShare.sendBundle(bundle);
    }
}
```

## Forge integration

In order to use `forge`, you need to have a running `Suave` node and the `suave` binary in your path.

To run `Suave` in development mode, use the following command:

```bash
$ suave --suave.dev
```

Then, your `forge` scripts/test must import the `SuaveEnabled` contract from the `suave-std/Test.sol` file.

```solidity
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "suave-std/Test.sol";
import "suave-std/Suave.sol";

contract TestForge is Test, SuaveEnabled {
    address[] public addressList = [0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829];

    function testConfidentialStore() public {
        Suave.DataRecord memory record = Suave.newDataRecord(0, addressList, addressList, "namespace");

        bytes memory value = abi.encode("suave works with forge!");
        Suave.confidentialStore(record.id, "key1", value);

        bytes memory found = Suave.confidentialRetrieve(record.id, "key1");
        assertEq(keccak256(found), keccak256(value));
    }
}
```

### Confidential inputs

Use the `setConfidentialInputs` function to set the confidential inputs during tests.

```solidity
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Test.sol";
import "src/suavelib/Suave.sol";

contract TestForge is Test, SuaveEnabled {
    function testConfidentialInputs() public {
        bytes memory input = hex"abcd";
        setConfidentialInputs(input);

        bytes memory found2 = Suave.confidentialInputs();
        assertEq0(input, found2);
    }
}
```

The value for the confidential inputs gets reset for each test.
