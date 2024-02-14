// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Test} from "forge-std/Test.sol";
import {ERC20Mintable} from "../src/ERC20Mintable.sol";

import {IUniswapV3Factory} from "v3-core/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "v3-core/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManagerModified} from "../src/modified_uniswap_casing/v3-periphery-modified/INonfungiblePositionManagerModified.sol";
import {ISwapRouterModified} from "../src/modified_uniswap_casing/v3-periphery-modified/ISwapRouterModified.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";
import {OracleLibrary} from "v3-periphery/libraries/OracleLibrary.sol";
import "forge-std/console.sol";

/**
 * @title UniV3PoolExplorer
 * @notice Sets up and explores a Uniswap v3 pool with with two ERC20 tokens,
 * sets up liquidity, and allows for simulation of swaps and price changes.
 * @dev Uses modified version of NonfungiblePositionManager to allow for
 * modifications of the pool. Original code enforces a check that a pool's
 * bytecode was not modified for security purposes.
 * @dev Imports are reliant on specific versioning to avoid compiler errors:
 * v3-core : release 0.8
 * v3-periphery : release 0.8
 * openzeppelin-contracts : release release-v4.0
 */
contract UniV3PoolExplorer is Test {
    ERC20Mintable public token0;
    ERC20Mintable public token1;
    address owner;
    address user;
    IUniswapV3Pool pool;
    INonfungiblePositionManagerModified positionManager;
    ISwapRouterModified swapRouter;
    address liquidityProvider;
    uint16 fee;

    /**
     * @notice Sets up the initial state of the Uniswap v3 pool and related components.
     * @dev Deploys ERC20 tokens, creates a Uniswap V3 pool, and provides initial liquidity.
     * Also sets up the modified Nonfungible Position Manager and Swap Router.
     */
    function setUp() public {
        owner = address(1);
        liquidityProvider = address(2);
        user = address(3);

        vm.startPrank(owner);
        address tokenA = address(new ERC20Mintable("A", "A"));
        address tokenB = address(new ERC20Mintable("B", "B"));
        if (tokenA < tokenB) {
            token0 = ERC20Mintable(tokenA);
            token1 = ERC20Mintable(tokenB);
        } else {
            token0 = ERC20Mintable(tokenB);
            token1 = ERC20Mintable(tokenA);
        }

        ERC20Mintable WETH = new ERC20Mintable("WETH", "WETH");

        uint256 tokenAmount = 10 ether;
        fee = 3000;

        token0.mint(liquidityProvider, tokenAmount);
        token1.mint(liquidityProvider, tokenAmount);

        IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(
            deployCode("UniswapV3FactoryModified.sol")
        );

        pool = IUniswapV3Pool(
            uniswapV3Factory.createPool(address(tokenA), address(tokenB), fee)
        );

        positionManager = INonfungiblePositionManagerModified(
            deployCode(
                "NonfungiblePositionManagerModified.sol",
                abi.encode(
                    address(uniswapV3Factory),
                    address(WETH),
                    "Test token descriptor",
                    address(pool)
                )
            )
        );

        swapRouter = ISwapRouterModified(
            deployCode(
                "SwapRouterModified.sol",
                abi.encode(
                    address(uniswapV3Factory),
                    address(WETH),
                    address(pool)
                )
            )
        );

        // ensure that starting tick is spaced properly and starts at 1:1
        int24 tickSpacing = pool.tickSpacing();
        int24 targetStartTick = 0;
        targetStartTick = targetStartTick < 0
            ? -((-targetStartTick / tickSpacing) * tickSpacing)
            : (targetStartTick / tickSpacing) * tickSpacing;

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(targetStartTick);
        pool.initialize(sqrtPriceX96);
        vm.stopPrank();

        // have LP supply liquidity
        vm.startPrank(liquidityProvider);
        token0.approve(address(positionManager), type(uint256).max);
        token1.approve(address(positionManager), type(uint256).max);

        // supply liquidty across whole range, adjusted for tick spacing needs
        int24 tickLower = -887272;
        int24 tickUpper = -tickLower;
        tickLower = tickLower < 0
            ? -((-tickLower / tickSpacing) * tickSpacing)
            : (tickLower / tickSpacing) * tickSpacing;
        tickUpper = tickUpper < 0
            ? -((-tickUpper / tickSpacing) * tickSpacing)
            : (tickUpper / tickSpacing) * tickSpacing;

        INonfungiblePositionManagerModified.MintParams
            memory mintParams = INonfungiblePositionManagerModified.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: tokenAmount,
                amount1Desired: tokenAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: liquidityProvider,
                deadline: block.timestamp + 10,
                pool: address(pool)
            });

        (
            ,
            /*uint256 tokenId*/
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = positionManager.mint(mintParams);
        console.log("Liquidity added: %d", liquidity);
        console.log("amount0: %d", amount0);
        console.log("amount1: %d", amount1);

        vm.stopPrank();

        // grow available observations in pool
        pool.increaseObservationCardinalityNext(10);
    }

    /**
     * @notice Prints the current price and tick information of the pool.
     * @dev Retrieves and logs the current sqrt price, tick, and the calculated token price based on the pool's state.
     */
    function printPrice() public view {
        (uint160 sqrt, int24 curTick, , , , , ) = pool.slot0();
        uint128 baseAmount = 10000;
        uint amount = OracleLibrary.getQuoteAtTick(
            curTick,
            baseAmount, // base amount
            address(token0), // base
            address(token1) // quote
        );
        console.log("Price 0<>1: %d<>%d", uint(baseAmount), uint(amount));
        console.log("slot0.tick:");
        console.logInt(curTick);
        console.log("slot0.sqrtX96:", sqrt);
    }

    /**
     * @notice Displays the user's balance for both tokens in the pool.
     * @dev Logs the current balance of token0 and token1 for the specified user address.
     */
    function printUserBalances() public view {
        console.log("user balance of 0: %d", token0.balanceOf(user));
        console.log("user balance of 1: %d", token1.balanceOf(user));
    }

    /**
     * @notice Internal helper function to fund an address and approve the pool for token transfers.
     * @param target The address to receive the funds and approvals.
     * @param amount0 Amount of token0 to mint and approve.
     * @param amount1 Amount of token1 to mint and approve.
     * @dev Mints specified amounts of token0 and token1 to the target address and approves them for the swap router.
     */
    function _fundAddressApprovePool(
        address target,
        uint256 amount0,
        uint256 amount1
    ) internal {
        vm.startPrank(owner);
        token0.mint(target, amount0);
        token1.mint(target, amount1);
        vm.stopPrank();
        vm.startPrank(target);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    /**
     * @notice Advances the block timestamp and number by one.
     * @dev This is a helper function for testing purposes to simulate the passage of time in the EVM.
     */
    function _incTime() public {
        console.log("[**inc time**]");
        uint256 blockTimestamp = block.timestamp + 1;
        uint256 blockNumber = block.number + 1;
        vm.warp(blockTimestamp);
        vm.roll(blockNumber);
    }

    /**
     * @notice Test for exploring the price impact of swaps.
     */
    function test_swapPriceImpact() public {
        _fundAddressApprovePool(user, 10 ether, 10 ether);
        uint swapIn = 1 ether;

        ISwapRouterModified.ExactInputSingleParams
            memory swapParamsGive0 = ISwapRouterModified
                .ExactInputSingleParams({
                    tokenIn: address(token0),
                    tokenOut: address(token1),
                    fee: fee,
                    recipient: user,
                    deadline: block.timestamp + 10,
                    amountIn: swapIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });

        ISwapRouterModified.ExactInputSingleParams
            memory swapParamsGive1 = ISwapRouterModified
                .ExactInputSingleParams({
                    tokenIn: address(token1),
                    tokenOut: address(token0),
                    fee: fee,
                    recipient: user,
                    deadline: block.timestamp + 10,
                    amountIn: swapIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });

        printPrice();
        vm.recordLogs();
        vm.startPrank(user);
        swapRouter.exactInputSingle(swapParamsGive0);
        printPrice();
        swapRouter.exactInputSingle(swapParamsGive0);
        printPrice();
        swapRouter.exactInputSingle(swapParamsGive1);
        swapRouter.exactInputSingle(swapParamsGive1);
        swapRouter.exactInputSingle(swapParamsGive1);
        swapRouter.exactInputSingle(swapParamsGive1);
        printPrice();
        vm.stopPrank();
    }
}
