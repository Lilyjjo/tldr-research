// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8;

interface IAuctionGuard {
    function setAdmin(address newAdmin) external;
    function setSuappKey(address newSuappKey) external;
    function enableAuction(bool setAuction) external;
    function postAuctionResults(
        address bidder,
        uint256 validBlock,
        uint256 price,
        bool auction,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function currentBlockAuctionDone() external view returns (bool);
    function getFeeAddress() external view returns (address);
    function auctionGuard() external;
}
