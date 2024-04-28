pragma solidity ^0.8;

import {IUniswapV3Pool} from "v3-core/interfaces/IUniswapV3Pool.sol";
import {IAuctionGuard} from "../interfaces/IAuctionGuard.sol";

interface IUniswapV3PoolAuctionedFirstSwap is IUniswapV3Pool, IAuctionGuard {}
