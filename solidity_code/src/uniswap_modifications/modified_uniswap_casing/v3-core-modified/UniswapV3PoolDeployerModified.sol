// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import {IUniswapV3PoolDeployerModified} from './IUniswapV3PoolDeployerModified.sol';

import {UniswapV3PoolAuctionedFirstSwap} from '../../UniswapV3PoolAuctionedFirstSwap.sol';

contract UniswapV3PoolDeployerModified is IUniswapV3PoolDeployerModified {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
        address auction;
    }

    /// @inheritdoc IUniswapV3PoolDeployerModified
    Parameters public override parameters;

    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The spacing between usable ticks
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing,
        address auction
    ) internal returns (address pool) {
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing, auction: auction});
        pool = address(new UniswapV3PoolAuctionedFirstSwap{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }
}
