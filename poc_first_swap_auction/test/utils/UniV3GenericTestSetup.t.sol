// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Test} from "forge-std/Test.sol";
import {ERC20Mintable} from "../../src/utils/ERC20Mintable.sol";

import {IUniswapV3Factory} from "v3-core/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "v3-core/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManagerModified} from "../../src/uniswap_modifications/modified_uniswap_casing/v3-periphery-modified/INonfungiblePositionManagerModified.sol";
import {ISwapRouterModified} from "../../src/uniswap_modifications/modified_uniswap_casing/v3-periphery-modified/ISwapRouterModified.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";
import {OracleLibrary} from "v3-periphery/libraries/OracleLibrary.sol";
import "forge-std/console.sol";

/**
 * @title UniV3GenericTestSetup
 * @notice Sets up a Uniswap v3 pool with associated router and position manager.
 * @dev Uses modified version of NonfungiblePositionManager to allow for
 * modifications of the pool. Original code enforces a check that a pool's
 * bytecode was not modified for security purposes.
 * @dev Imports are reliant on specific versioning to avoid compiler errors:
 * v3-core : release 0.8
 * v3-periphery : release 0.8
 * openzeppelin-contracts : release release-v4.0
 */
contract UniV3GenericTestSetup is Test {
    ERC20Mintable public token0;
    ERC20Mintable public token1;

    IUniswapV3Pool pool;
    INonfungiblePositionManagerModified positionManager;
    ISwapRouterModified swapRouter;
    
    uint16 constant POOL_FEE = 3000;
    address poolOwner;
    
    uint256 nextAddress;

    struct ExpectedRevert {
        bool shouldRevert;
        bytes4 errorSelector;
    }

    function _nextAddress() internal returns (address) {
        return address(bytes20(keccak256(abi.encode(nextAddress++))));
    } 

    /**
     * @notice Advances the block timestamp and number by one.
     */
    function _incTime() public {
        uint256 blockTimestamp = block.timestamp + 1;
        uint256 blockNumber = block.number + 1;
        vm.warp(blockTimestamp);
        vm.roll(blockNumber);
    }

    /**
     * @notice Sets up the initial state of the Uniswap v3 pool and related components.
     * @dev Deploys ERC20 tokens, creates a Uniswap V3 pool, and sets up the
     * modified Nonfungible Position Manager and Swap Router.
     */
    function setUp() virtual public {
        // initialize addresses 
        poolOwner = _nextAddress();

        vm.startPrank(poolOwner);

        // initialize token0/token1/WETH
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

        // initialize Factory
        IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(
            deployCode("UniswapV3FactoryModified.sol")
        );

        // initialize Pool
        pool = IUniswapV3Pool(
            uniswapV3Factory.createPool(address(tokenA), address(tokenB), POOL_FEE)
        );

        int24 tickSpacing = pool.tickSpacing();
        int24 targetStartTick = 0;
        targetStartTick = targetStartTick < 0
            ? -((-targetStartTick / tickSpacing) * tickSpacing)
            : (targetStartTick / tickSpacing) * tickSpacing;

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(targetStartTick);
        pool.initialize(sqrtPriceX96);

        // grow available observations in pool
        pool.increaseObservationCardinalityNext(10);

        // initialize PositionManager
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

        // initialize swapRouter
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

        vm.stopPrank();
    }

    /**
     * @notice Helper function to give funds and approve a third
     * party to spend those funds.
     */
    function _fundAndApprove(
        address user,
        address approved,
        ERC20Mintable token,
        uint256 amount
    ) internal {
        vm.startPrank(poolOwner);
        token.mint(user, amount);
        vm.stopPrank();
        vm.startPrank(user);
        token.approve(approved, type(uint256).max);
        vm.stopPrank();
    }

    /**
     * @notice Performs swap.
     */
    function _swap(address swapper, ERC20Mintable tokenIn, uint256 amountIn, uint256 amountOut, bool mintTokens, ExpectedRevert memory revertParams) internal {
        ERC20Mintable tokenOut = tokenIn == token0 ? token1 : token0; 
        
        if(mintTokens) {
            // mint swapper tokens 
            _fundAndApprove(swapper, address(swapRouter), tokenIn, amountIn);
        }

        ISwapRouterModified.ExactInputSingleParams memory swapParams; 
        swapParams = ISwapRouterModified
        .ExactInputSingleParams({
                tokenIn: address(tokenIn),
                tokenOut: address(tokenOut),
                fee: POOL_FEE,
                recipient: swapper,
                deadline: block.timestamp + 10,
                amountIn: amountIn,
                amountOutMinimum: amountOut,
                sqrtPriceLimitX96: 0
        });

        if(revertParams.shouldRevert) vm.expectRevert(revertParams.errorSelector);
        swapRouter.exactInputSingle(swapParams);
    }

    /**
     * @notice Adds liquidity.
     */
    function _addLiquidity(address liquidityProvider, uint256 token0Amount, uint256 token1Amount, bool mintTokens) internal returns (uint256, uint256) {
        if(mintTokens) {
            // mint liquidity provider tokens
            _fundAndApprove(liquidityProvider, address(positionManager), token0, token0Amount);
            _fundAndApprove(liquidityProvider, address(positionManager), token1, token1Amount);
        }
        vm.startPrank(liquidityProvider);

        // supply liquidty across whole range, adjusted for tick spacing needs
        int24 tickSpacing = pool.tickSpacing();
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
                fee: POOL_FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: token0Amount,
                amount1Desired: token1Amount,
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
        vm.stopPrank();

        // console.log("Liquidity added: %d", liquidity);
        // console.log("amount0: %d", amount0);
        // console.log("amount1: %d", amount1);

        return (amount0, amount1);
    }

    /**
     * @notice Displays the user's balance for both tokens in the pool.
     */
    function printUserBalances(address user) public view {
        console.log("user balance of 0: %d", token0.balanceOf(user));
        console.log("user balance of 1: %d", token1.balanceOf(user));
    }

    /**
    * @notice Prints the current price.
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
        //console.log("slot0.tick:");
        //console.logInt(curTick);
        //console.log("slot0.sqrtX96:", sqrt);
    }
}
