// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Test} from "forge-std/Test.sol";
import {ERC20Mintable} from "../src/ERC20Mintable.sol";

import {IUniswapV3Factory} from "v3-core/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "v3-core/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManagerModified} from "./modified_uniswap/v3-periphery-modified/INonfungiblePositionManagerModified.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";
import "forge-std/console.sol";

contract UniV3TwapNotSafe is Test {
    ERC20Mintable public tokenA;
    ERC20Mintable public tokenB;
    address owner;
    IUniswapV3Pool pool;
    INonfungiblePositionManagerModified positionManager;
    address liquidityProvider;

    /**
     * @notice Sets up a Uniswapv3 pool with: two tokens of 18 decimal places,
     * starting price of 1 tokenA/tokenB, and liquidty across the whole tick range.
     * @dev Uses modified version of NonfungiblePositionManager to allow for
     * modifications of the pool. Original code enforces a check that a pool's
     * bytecode was not modified for security purposes.
     * @dev Imports are reliant on specific versioning to avoid compiler errors:
     * v3-core : release 0.8
     * v3-periphery : release 0.8
     * openzeppelin-contracts : release release-v4.0
     */
    function setUp() public {
        owner = address(1);
        liquidityProvider = address(2);

        vm.startPrank(owner);
        tokenA = new ERC20Mintable("A", "A");
        tokenB = new ERC20Mintable("B", "B");
        ERC20Mintable WETH = new ERC20Mintable("WETH", "WETH");

        uint256 tokenAmount = 10 ether;
        uint16 fee = 3000;

        tokenA.mint(liquidityProvider, tokenAmount);
        tokenB.mint(liquidityProvider, tokenAmount);

        IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(
            deployCode("UniswapV3Factory.sol")
        );

        positionManager = INonfungiblePositionManagerModified(
            deployCode(
                "NonfungiblePositionManagerModified.sol",
                abi.encode(
                    address(uniswapV3Factory),
                    address(WETH),
                    "Test token descriptor"
                )
            )
        );

        pool = IUniswapV3Pool(
            uniswapV3Factory.createPool(address(tokenA), address(tokenB), fee)
        );

        // ensure that starting tick is spaced properly with goal price of tokenA/tokenB == 1
        int24 tickSpacing = pool.tickSpacing();
        int24 targetStartTick = 414428;
        targetStartTick = targetStartTick < 0
            ? -((-targetStartTick / tickSpacing) * tickSpacing)
            : (targetStartTick / tickSpacing) * tickSpacing;

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(targetStartTick);
        pool.initialize(sqrtPriceX96);
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        tokenA.approve(address(positionManager), type(uint256).max);
        tokenB.approve(address(positionManager), type(uint256).max);

        address token0 = address(tokenA) < address(tokenB)
            ? address(tokenA)
            : address(tokenB);
        address token1 = address(tokenA) < address(tokenB)
            ? address(tokenB)
            : address(tokenA);

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
                token0: token0,
                token1: token1,
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

        positionManager.mint(mintParams);
        vm.stopPrank;
    }

    function test_GetLiquidityBalance() public {}

    function testFuzz_SetNumber(uint256 x) public {}
}
