pragma solidity ^0.8;

import {IERC20Minimal} from 'v3-core/interfaces/IERC20Minimal.sol';
import {IAuctionGuard} from './IAuctionGuard.sol';
import {IAuctionDeposits} from "./IAuctionDeposits.sol";

contract AuctionGuard is IAuctionGuard {
    IAuctionDeposits public auctionDeposits;  
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

    event AuctioneerChanged(address indexed _oldAuctioneer, address indexed _newAuctioneer);
    event SuappKeyChanged(address indexed _oldSuappKey, address indexed _newSuappKey);
    event FeeAddressChanged(address indexed _oldFeeAddress, address indexed _newFeeAddress);

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

    function setAuctioneer(address newAuctioneer) external onlyAuctioneer {
        if (newAuctioneer == address(0)) revert ZeroAddress();
        address oldAuctioneer = auctioneer;
        auctioneer = newAuctioneer;
        emit AuctioneerChanged(oldAuctioneer, auctioneer);
    }

    function setSuappKey(address newSuappKey) external onlyAuctioneer {
        if (newSuappKey == address(0)) revert ZeroAddress();
        address oldSuappKey = suappKey;
        suappKey = newSuappKey;
        emit SuappKeyChanged(oldSuappKey, newSuappKey);
    }

    function setFeeAddress(address newFeeAddress) external onlyAuctioneer {
        if (newFeeAddress == address(0)) revert ZeroAddress();
        address oldFeeAddress = auctionFeeDistributor;
        auctionFeeDistributor = newFeeAddress;
        emit FeeAddressChanged(oldFeeAddress, newFeeAddress);
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

    function postAuctionResults(
        address bidder, 
        uint256 validBlock, 
        uint256 price, 
        bool auction, 
        uint8 v,
        bytes32 r,
        bytes32 s
    ) onlySuappKey external {
        if(!auctionsEnabled) revert AuctionsNotRunning();
        if(lastSwapBlock == block.number || firstSwapValidBlock == block.number) revert AuctionAlreadyPosted();
        if(auction == false) {
            // let all swaps run without auction
            lastSwapBlock = block.number;
        } else {
            // try colleting payment
            bool successfulPayment;
            try auctionDeposits.withdrawBid(bidder, validBlock, price, v, r, s) returns (bool success) {
                // TODO ensure wrong / missing returns doesn't mess things up
                successfulPayment = success;
            } catch {
                successfulPayment = false;
            }

            if(successfulPayment) {
                // enable first protected swap
                firstSwapTxOrigin = bidder;
                firstSwapValidBlock = validBlock;
            } else {
                // auction payment failed, let all swaps pass
                lastSwapBlock = block.number;
            }
        }
    } 

    // returns if auction has completed or not for the current block 
    // helper function for deposit contract
    function currentBlockAuctionDone() external view returns (bool) {
        return !auctionsEnabled || lastSwapBlock == block.number;
    }

    function getFeeAddress() external view returns (address) {
        return auctionFeeDistributor;
    }
 
}