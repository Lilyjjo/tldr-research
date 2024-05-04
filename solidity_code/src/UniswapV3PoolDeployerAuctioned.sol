// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import {IUniswapV3PoolDeployerAuctioned} from "./interfaces/IUniswapV3PoolDeployerAuctioned.sol";

import {UniswapV3PoolAuctioned} from "./UniswapV3PoolAuctioned.sol";

//import "forge-std/console.sol";

contract UniswapV3PoolDeployerAuctioned is IUniswapV3PoolDeployerAuctioned {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
        address auction;
    }

    /// @inheritdoc IUniswapV3PoolDeployerAuctioned
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
        parameters = Parameters({
            factory: factory,
            token0: token0,
            token1: token1,
            fee: fee,
            tickSpacing: tickSpacing,
            auction: auction
        });
        pool = address(
            new UniswapV3PoolAuctioned{
                salt: keccak256(abi.encode(token0, token1, fee))
            }()
        );

        //Code for generating POOL_INIT_CODE_HASH

        //console.logBytes32(
        //    keccak256(
        //        abi.encodePacked(type(UniswapV3PoolAuctioned).creationCode)
        //    )
        //);

        delete parameters;
    }
}
