// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8;

interface IAuctionDeposits {
    function setAuction(address auction) external;

    function withdrawBid(
        address bidder,
        uint256 blockNumber,
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (bool);

    function deposit() external payable;

    function balanceOf(address user) external returns (uint256);
}
