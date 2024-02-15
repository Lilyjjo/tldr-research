pragma solidity ^0.8;

import {IUniswapV3Pool} from "v3-core/interfaces/IUniswapV3Pool.sol";

interface IUniswapV3PoolAuctionedFirstSwap is
    IUniswapV3Pool
{
    function setAuctioneer(address newAuctioneer) external;
    function setSuappKey(address newSuappKey) external;
    function enableAuction(bool setAuction) external;
    function postAuctionResults(address firstSwapper, uint256 validBlock, bool auction) external;
}
