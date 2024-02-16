pragma solidity ^0.8;

interface IAuctionDeposits {
    function withdrawBid(
        address bidder,
        uint256 blockNumber, 
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (bool);
}
