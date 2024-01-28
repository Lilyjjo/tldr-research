// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ChainInfo
 * @notice Contract to be called from Suave to get current chain params
 * @author @lilyjjo
 */
contract GoerliChainInfo {
    uint256 public testSlot_;

    constructor() {
        testSlot_ = 666;
    }

    /**
     * @notice Retrieves the current gas price from the latest transaction
     * @return gasPrice The gas price of the latest transaction in wei
     */
    function getGasPrice() external view returns (uint256 gasPrice) {
        gasPrice = tx.gasprice;
    }

    /**
     * @notice Gets the current block number
     * @return blockNum The number of the current block
     */
    function getBlockNum() external view returns (uint256 blockNum) {
        blockNum = block.number;
    }

    /**
     * @notice Function for debugging ethCall precompile
     * @return testSlot Storge value
     */
    function testSlot() external view returns (uint256) {
        return testSlot_;
    }
}
