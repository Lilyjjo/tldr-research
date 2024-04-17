// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IAMMAuctionSuapp
 * @author lilyjjo
 */
interface IAMMAuctionSuapp {
    function newPendingTxn() external returns (bytes memory);
    function newBid(string memory salt) external returns (bytes memory);
    function runAuction(
        uint256 signingKeyNonce
    ) external returns (bytes memory);
    function setSigningKey() external returns (bytes memory);
    function setSepoliaUrl() external returns (bytes memory);
    function initLastL1Block() external returns (bytes memory);
}
