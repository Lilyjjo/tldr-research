// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IAuctionSuapp
 * @author lilyjjo
 */
interface IAuctionSuapp {
    function newPendingTxn() external returns (bytes memory);
    function newBid(string memory salt) external returns (bytes memory);
    function runAuction() external returns (bytes memory);
    function setSigningKey(address pubkey) external returns (bytes memory);
    function setL1Url() external returns (bytes memory);
    function setBundleUrl() external returns (bytes memory);
    function initLastL1Block() external returns (bytes memory);
    function _resetSwaps() external returns (bytes memory);
}
