## Uniswap Modifications
The goal was to minimally modify the Uniswap setup. 

List of v3-core non-pool modifications:
- Added the `AuctionGuard` as a parameter to the `UniswapV3Factory`'s `createPool()` function.
- Passed the auction argument to the `UniswapV3PoolDeployer`'s function.

List of v3-periphery modifications:
- Changed the `INIT_POOL_CODE_HASH` in `PoolAddress` to reflect the new init code hash of the new pool logic.
- Note: this was done in a git submodule to keep the codebase clean.

List of modifications made to the `UniswapV3Pool`:
- Exposed the `AuctionGuard` contract as a passed in constructor parameter.
- Modified the `swap()` and `burn()` functions to call into the Auction Guard.
- Removed a few emits in other parts of the code to make room for the additional code.

Diff of the logic changes in the UniswapV3 pool:
```diff
diff --git a/src/UniswapV3Pool.sol b/src/UniswapV3PoolAuctioned.sol
index 025804e..fc56565 100644
--- a/src/UniswapV3Pool.sol
+++ b/src/UniswapV3PoolAuctioned.sol
@@ -1,31 +1,35 @@
 // SPDX-License-Identifier: BUSL-1.1
 pragma solidity =0.8.12;
-contract UniswapV3Pool is IUniswapV3Pool, NoDelegateCall {
+
+import {IAuctionGuard} from "./interfaces/IAuctionGuard.sol";
+
+contract UniswapV3PoolAuctioned is IUniswapV3Pool, NoDelegateCall {
     using SafeCast for uint256;
     using SafeCast for int256;
     using Tick for mapping(int24 => Tick.Info);
@@ -94,6 +98,8 @@ contract UniswapV3Pool is IUniswapV3Pool, NoDelegateCall {
     /// @inheritdoc IUniswapV3PoolState
     Oracle.Observation[65535] public override observations;
 
+    IAuctionGuard public auction;
+
     /// @dev Mutually exclusive reentrancy protection into the pool to/from a method. This method also prevents entrance
     /// to a function before the pool is initialized. The reentrancy guard is required throughout the contract because
     /// we use balance checks to determine the payment status of interactions such as mint, swap and flash.
@@ -112,10 +118,12 @@ contract UniswapV3Pool is IUniswapV3Pool, NoDelegateCall {
 
     constructor() {
         int24 _tickSpacing;
-        (factory, token0, token1, fee, _tickSpacing) = IUniswapV3PoolDeployer(
+        address _auction;
+        (factory, token0, token1, fee, ) = IUniswapV3PoolDeployerAuctioned(
             msg.sender
         ).parameters();
         tickSpacing = _tickSpacing;
+        auction = IAuctionGuard(_auction);
 
         maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(
             _tickSpacing
@@ -598,6 +606,7 @@ contract UniswapV3Pool is IUniswapV3Pool, NoDelegateCall {
         int24 tickUpper,
         uint128 amount
     ) external override lock returns (uint256 amount0, uint256 amount1) {
+        auction.auctionGuard();
         unchecked {
             (
                 Position.Info storage position,
@@ -696,6 +705,7 @@ contract UniswapV3Pool is IUniswapV3Pool, NoDelegateCall {
         noDelegateCall
         returns (int256 amount0, int256 amount1)
     {
+        auction.auctionGuard();
         if (amountSpecified == 0) revert AS();
 
         Slot0 memory slot0Start = slot0;

```
