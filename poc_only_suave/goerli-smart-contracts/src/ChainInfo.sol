// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ChainInfo
 * @notice Contract to be called from Suave to get current chain params
 * @author @lilyjjo
 */
contract ChainInfo {
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
}
