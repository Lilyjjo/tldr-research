// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8;

import {IUniswapV3Pool} from "v3-core/interfaces/IUniswapV3Pool.sol";
import {IAuctionGuard} from "../interfaces/IAuctionGuard.sol";

interface IUniswapV3PoolAuctioned is IUniswapV3Pool, IAuctionGuard {}
