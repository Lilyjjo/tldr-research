pragma solidity ^0.8;

import {IERC20Minimal} from 'v3-core/interfaces/IERC20Minimal.sol';
import {IAuctionGuard} from './IAuctionGuard.sol';

contract AuctionGuard is IAuctionGuard {
    address public auctionFeeDistributor;
    address public firstSwapTxOrigin;
    uint256 public firstSwapValidBlock;
    uint256 public lastSwapBlock;
    IERC20Minimal public paymentToken;
    bool public auctionsEnabled;
    address public suappKey;
    address public auctioneer;

    error WrongValidSwapBlock();
    error WrongFirstSwapper();
    error AuctionsNotRunning();
    error AuctionAlreadyPosted();
    error OnlyAuctioneer();
    error OnlySuappKey();
    error ZeroAddress();

    event SuappKeyChanged(address indexed _oldSuappKey, address indexed _newSuappKey);
    event AuctioneerChanged(address indexed _oldAuctioneer, address indexed _newAuctioneer);
    event AuctionsEnabled(bool enabled);
    
    modifier onlyAuctioneer() {
        // note: this is unsafe and initial auctioneer should be set in a constructor
        if (auctioneer != address(0) && msg.sender != auctioneer) revert OnlyAuctioneer();
        _;
    }

    modifier onlySuappKey() {
        if (msg.sender != suappKey) revert OnlySuappKey();
        _;
    }

    function setSuappKey(address newSuappKey) external onlyAuctioneer {
        if (newSuappKey == address(0)) revert ZeroAddress();
        address oldSuappKey = suappKey;
        suappKey = newSuappKey;
        emit SuappKeyChanged(oldSuappKey, newSuappKey);
    }

    function setAuctioneer(address newAuctioneer) external onlyAuctioneer {
        if (newAuctioneer == address(0)) revert ZeroAddress();
        address oldAuctioneer = auctioneer;
        auctioneer = newAuctioneer;
        emit AuctioneerChanged(oldAuctioneer, auctioneer);
    }

    function enableAuction(bool setAuction) onlySuappKey external {
        auctionsEnabled = setAuction;
        lastSwapBlock = block.number; // unsafe to run auction in enabling block 
        emit AuctionsEnabled(auctionsEnabled);
    }

    modifier auctionGuard() {
        if(auctionsEnabled && lastSwapBlock < block.number){
            // Ensure swapper is auction winner
            if(block.number != firstSwapValidBlock) revert WrongValidSwapBlock();
            if(tx.origin != firstSwapTxOrigin) revert WrongFirstSwapper();
            // let rest of swaps pass
            lastSwapBlock = block.number;
        } 
        _;
    }

    function postAuctionResults(address firstSwapper, uint256 validBlock, uint256 price, bool auction) onlySuappKey external {
        if(!auctionsEnabled) revert AuctionsNotRunning();
        if(lastSwapBlock == block.number || firstSwapValidBlock == block.number) revert AuctionAlreadyPosted();
        if(auction == false) {
            // let all swaps run without auction
            lastSwapBlock = block.number;
        } else {
            // try colleting payment
            bool successfulPayment;
            try paymentToken.transferFrom(firstSwapper, auctionFeeDistributor, price) returns (bool success) {
                // TODO ensure wrong / missing returns doesn't mess things up
                successfulPayment = success;
            } catch {
                successfulPayment = false;
            }

            if(successfulPayment) {
                // enable first protected swap
                firstSwapTxOrigin = firstSwapper;
                firstSwapValidBlock = validBlock;
            } else {
                // auction payment failed, let all swaps pass
                lastSwapBlock = block.number;
            }
        }
    } 

    
}