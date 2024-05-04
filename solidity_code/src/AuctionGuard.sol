// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {IERC20Minimal} from "v3-core/interfaces/IERC20Minimal.sol";
import {IAuctionGuard} from "./interfaces/IAuctionGuard.sol";
import {IAuctionDeposits} from "./interfaces/IAuctionDeposits.sol";

/**
 * @title AuctionGuard
 * @author lilyjjo
 *
 * @dev Used with `AuctionSuapp` to guard functions with an auction.
 *
 *  To check from a different contract if the auction has completed,
 *  call `AuctionGuard.auctionGuard()`. This function will unlock
 *  if the auction had no winner or if the auction winner invokes the
 *  function.
 */
contract AuctionGuard is IAuctionGuard {
    // If the auctionGuard() is enforcing auction completion
    bool public auctionsEnabled;
    // The address of the private key stored in the AuctionSuapp
    // that is signing the `postAuctionResults()` transactions
    address public suappKey;

    // Admin of this contract
    address public admin;

    // Details for the associated AuctionDeposits funciton
    IAuctionDeposits public auctionDeposits;
    IERC20Minimal public paymentToken;

    // Address to receive the auction proceeds
    address public auctionFeeDistributor;

    // The last block which had it's auction conclude
    uint256 public lastConcludedBlock;
    // The auction winner's info
    address public winnerTxOrigin;
    uint256 public winnerValidBlock;

    // Errors
    error WrongValidWinnerBlock();
    error WrongWinner();
    error AuctionsNotRunning();
    error AuctionAlreadyPosted();
    error OnlyAdmin();
    error OnlySuappKey();
    error ZeroAddress();

    // Events
    event AuctionsEnabled(bool enabled);
    event AuctionSucceeded();
    event SuccessfulPayment();
    event AdminChanged(address indexed _oldAdmin, address indexed _newAdmin);

    event SuappKeyChanged(
        address indexed _oldSuappKey,
        address indexed _newSuappKey
    );
    event FeeAddressChanged(
        address indexed _oldFeeAddress,
        address indexed _newFeeAddress
    );

    /**
     * @dev Setup the AuctionGuard
     * @param auctionDeposits_ The address of the auction deposits contract.
     * @param suappKey_ The address of the SuappKey.
     */
    constructor(address auctionDeposits_, address suappKey_) {
        auctionDeposits = IAuctionDeposits(auctionDeposits_);
        suappKey = suappKey_;
        auctionsEnabled = true;
        admin = msg.sender;
        auctionFeeDistributor = msg.sender;
    }

    /**
     * @dev Modifier to restrict function access to the admin.
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    /**
     * @dev Modifier to restrict function access to the SuappKey.
     */
    modifier onlySuappKey() {
        if (msg.sender != suappKey) revert OnlySuappKey();
        _;
    }

    /**
     * @dev Sets the admin address.
     * @param newAdmin The address of the new admin.
     */
    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, admin);
    }

    /**
     * @dev Sets the SuappKey address.
     * @param newSuappKey The address of the new SuappKey.
     */
    function setSuappKey(address newSuappKey) external onlyAdmin {
        if (newSuappKey == address(0)) revert ZeroAddress();
        address oldSuappKey = suappKey;
        suappKey = newSuappKey;
        emit SuappKeyChanged(oldSuappKey, newSuappKey);
    }

    /**
     * @dev Sets the fee address.
     * @param newFeeAddress The address of the new fee address.
     */
    function setFeeAddress(address newFeeAddress) external onlyAdmin {
        if (newFeeAddress == address(0)) revert ZeroAddress();
        address oldFeeAddress = auctionFeeDistributor;
        auctionFeeDistributor = newFeeAddress;
        emit FeeAddressChanged(oldFeeAddress, newFeeAddress);
    }

    /**
     * @dev Enables or disables auctions.
     * @param setAuction True to enable auctions, false to disable.
     */
    function enableAuction(bool setAuction) external onlyAdmin {
        auctionsEnabled = setAuction;
        lastConcludedBlock = block.number; // unsafe to run auction in enabling block
        emit AuctionsEnabled(auctionsEnabled);
    }

    /**
     * @dev Any contract which calls this will have that function guarded
     * by the auction.
     */
    function auctionGuard() external {
        if (auctionsEnabled && lastConcludedBlock < block.number) {
            // Ensure swapper is auction winner
            if (block.number != winnerValidBlock)
                revert WrongValidWinnerBlock();
            if (tx.origin != winnerTxOrigin) revert WrongWinner();
            // let rest of swaps pass
            lastConcludedBlock = block.number;
        }
    }

    /**
     * @dev Posts auction results.
     * @param bidder The address of the bidder.
     * @param validBlock The valid block number for these auction results.
     * @param price The price of winning the auction.
     * @param auction True if it's an auction, false otherwise.
     * @param v The v parameter of the signature.
     * @param r The r parameter of the signature.
     * @param s The s parameter of the signature.
     */
    function postAuctionResults(
        address bidder,
        uint256 validBlock,
        uint256 price,
        bool auction,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlySuappKey {
        // ensure auctions are running
        if (!auctionsEnabled) revert AuctionsNotRunning();
        // check that bid is not stale
        if (
            lastConcludedBlock == block.number ||
            winnerValidBlock == block.number
        ) revert AuctionAlreadyPosted();

        // check if the auction had a winner
        if (auction == false) {
            // let all swaps run without auction
            lastConcludedBlock = block.number;
        } else {
            // try colleting payment
            bool successfulPayment;
            try
                auctionDeposits.withdrawBid(bidder, validBlock, price, v, r, s)
            returns (bool success) {
                successfulPayment = success;
            } catch {
                successfulPayment = false;
            }

            if (successfulPayment) {
                // enable first protected swap
                winnerTxOrigin = bidder;
                winnerValidBlock = validBlock;
                emit SuccessfulPayment(); // note: is read in suave app
            } else {
                // auction payment failed, let all swaps pass
                lastConcludedBlock = block.number;
            }
        }
    }

    /**
     * @dev Checks if the auction for the current block is done.
     * @dev this is different from `auctionGuard()` because it doesn't
     * revert or trigger the auction to have concluded.
     * @return True if the auction is done, false otherwise.
     */
    function currentBlockAuctionDone() external view returns (bool) {
        return !auctionsEnabled || lastConcludedBlock == block.number;
    }

    /**
     * @dev Gets the fee address.
     * @return The fee address.
     */
    function getFeeAddress() external view returns (address) {
        return auctionFeeDistributor;
    }
}
