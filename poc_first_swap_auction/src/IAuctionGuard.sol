pragma solidity ^0.8;

interface IAuctionGuard
{
    function setAuctioneer(address newAuctioneer) external;
    function setSuappKey(address newSuappKey) external;
    function enableAuction(bool setAuction) external;
    function postAuctionResults(address firstSwapper, uint256 validBlock, uint256 price, bool auction) external;
}
