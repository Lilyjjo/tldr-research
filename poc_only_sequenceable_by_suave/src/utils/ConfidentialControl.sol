// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Suave} from "suave-std/suavelib/Suave.sol";

// Updated port from: https://github.com/halo3mic/suave-playground/blob/9afe269ab2da983ca7314b68fcad00134712f4c0/contracts/blockad/lib/ConfidentialControl.sol 

abstract contract ConfidentialControl  {
    string public constant S_NAMESPACE = "SECRET";
	Suave.DataId public secretDataId;
	bytes32 public presentHash;
	uint public nonce;

	struct UnlockArgs {
		bytes32 key;
		bytes32 nextHash;
	}
    error SuaveError(string message);

	modifier unlock(UnlockArgs calldata unlockPair) {
        crequire(isValidKey(unlockPair.key), "Invalid key");
		_;
		presentHash = unlockPair.nextHash;
		nonce++;
	}

    modifier onlyConfidential() {
		crequire(Suave.isConfidential(), "Not confidential");
		_;
	}

    function crequire(bool condition, string memory message) internal pure {
		if (!condition) {
			revert SuaveError(message);
		}
	}

	/**********************************************************************
	 *                           ⛓️ ON-CHAIN METHODS                       *
	 ***********************************************************************/

	function ccCallback(bytes32 nextHash, Suave.DataId sDataId) external {
		crequire(!isInitialized(), "Already initialized");
		presentHash = nextHash;
		secretDataId = sDataId;
	}

	function isInitialized() public view returns (bool) {
		return presentHash != 0;
	}

	/**********************************************************************
	 *                         🔒 CONFIDENTIAL METHODS                      *
	 ***********************************************************************/

	function confidentialConstructor() public view virtual onlyConfidential returns (bytes memory) {
		crequire(!isInitialized(), "Already initialized");
		bytes memory secret = Suave.confidentialInputs();
		Suave.DataId sDataId = storeSecret(secret);
		bytes32 nextHash = makeHash(abi.decode(secret, (bytes32)), nonce);
		return abi.encodeWithSelector(this.ccCallback.selector, nextHash, sDataId);
	}

	/**********************************************************************
	 *                         🛠️ INTERNAL METHODS                          *
	 ***********************************************************************/

	function storeSecret(bytes memory secret) internal view returns (Suave.DataId) {
		address[] memory peekers = new address[](1);
		peekers[0] = address(this);
		Suave.DataRecord memory secretBid = Suave.newDataRecord(10, peekers, peekers, "poke_relayer:v0:secret");
		Suave.confidentialStore(secretBid.id, S_NAMESPACE, secret);
		return secretBid.id;
	}

	function isValidKey(bytes32 key) internal view returns (bool) {
		return keccak256(abi.encode(key)) == presentHash;
	}

	function getUnlockPair() internal view returns (UnlockArgs memory) {
		return UnlockArgs(getKey(nonce), getHash(nonce + 1));
	}

	function getHash(uint _nonce) internal view returns (bytes32) {
		return keccak256(abi.encode(getKey(_nonce)));
	}

	function getKey(uint _nonce) internal view returns (bytes32) {
		return makeKey(getSecret(), _nonce);
	}

	function makeHash(bytes32 secret, uint _nonce) internal pure returns (bytes32) {
		return keccak256(abi.encode(makeKey(secret, _nonce)));
	}

	function makeKey(bytes32 secret, uint _nonce) internal pure returns (bytes32) {
		return keccak256(abi.encode(secret, _nonce));
	}

	function getSecret() internal view returns (bytes32) {
		bytes memory secretB = Suave.confidentialRetrieve(secretDataId, S_NAMESPACE);
		return abi.decode(secretB, (bytes32));
	}
}