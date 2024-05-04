pragma solidity ^0.8;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {EIP712} from "openzeppelin-contracts/utils/cryptography/draft-EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {IAuctionGuard} from "./interfaces/IAuctionGuard.sol";
import {IAuctionDeposits} from "./interfaces/IAuctionDeposits.sol";

/**
 * @title AuctionDeposits
 * @author lilyjjo
 *
 * @dev A contract for managing deposits and withdrawals for an `AuctionGuard`.
 */
contract AuctionDeposits is Ownable, EIP712, IAuctionDeposits {
    // Associated AuctionGuard
    IAuctionGuard public auctionGuard;

    // Internal bidder's balances
    mapping(address => uint256) public balances;

    // Block of last processed auction, used for replay
    // protection
    uint256 public lastAuction;

    // Hash of the bid type for EIP-712 compliance.
    bytes32 public constant WITHDRAW_BID_TYPEHASH =
        keccak256(
            "WithdrawBid(address bidder,uint256 blockNumber,uint256 amount)"
        );

    error OnlyAuction();
    error AuctionAlreadySet();
    error AuctionNotDone();
    error AuctionAlreadyWithdrawn();
    error WrongBlockNumber();
    error WrongSigner();
    error NotEnoughFunds();
    error ZeroAddress();
    error TransferError(bytes error);

    event Deposit(address depositee, address depositor, uint256 amount);
    event Withdraw(address from, address to, uint256 amount);
    event EnforceSequencing(bool enabled);

    /**
     * @dev Setup the domain information for EIP712
     */
    constructor() Ownable() EIP712("AuctionDeposits", "v1") {}

    /**
     * @dev Modifier to restrict function access to the auctionGuard.
     */
    modifier onlyAuction() {
        if (msg.sender != address(auctionGuard)) revert OnlyAuction();
        _;
    }

    /**
     * @dev Modifier to restrict function access to the SuappKey.
     */
    function setAuctionGuard(address auctionGuard_) external onlyOwner {
        if (address(auctionGuard) != address(0)) revert AuctionAlreadySet();
        auctionGuard = IAuctionGuard(auctionGuard_);
    }

    /**
     * @dev Deposits funds into the contract for a potential bidder.
     * Bidders must have funds in this contract to cover their bidded amount,
     * else their bids will fail to be considered.
     */
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.sender, msg.value);
    }

    /**
     * @dev Gets the balance of a bidder.
     * @param bidder The address of the bidder.
     * @return The balance of the bidder.
     */
    function balanceOf(address bidder) external view returns (uint256) {
        return balances[bidder];
    }

    /**
     * @dev Withdraws funds from the contract to a specified address.
     * Will revert if the auction is not done to help ensure that
     * bids have the expected funds.
     * @param to The address to which the funds are withdrawn.
     * @param amount The amount to withdraw.
     */
    function withdraw(address to, uint256 amount) external {
        // check if auction ongoing
        if (!auctionGuard.currentBlockAuctionDone()) {
            revert AuctionNotDone();
        }

        // checks
        if (to == address(0)) revert ZeroAddress();
        if (balances[msg.sender] < amount) revert NotEnoughFunds();

        // book keeping
        balances[msg.sender] -= amount;

        // send funds
        (bool success, bytes memory error) = to.call{value: amount}("");
        if (!success) revert TransferError(error);

        emit Withdraw(msg.sender, to, amount);
    }

    /**
     * @dev Withdraws the winning bid from an auction.
     * Is only callable from the configured auction guard.
     * @param bidder The address of the bidder, must have at least amount deposited.
     * @param blockNumber The block number of the bid.
     * @param amount The amount of the bid.
     * @param v The v parameter of the signature.
     * @param r The r parameter of the signature.
     * @param s The s parameter of the signature.
     * @return True if the withdrawal is successful, false otherwise.
     */
    function withdrawBid(
        address bidder,
        uint256 blockNumber,
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyAuction returns (bool) {
        if (blockNumber != block.number) revert WrongBlockNumber();
        if (lastAuction == block.number) revert AuctionAlreadyWithdrawn();
        lastAuction = block.number;

        bytes32 structHash = keccak256(
            abi.encode(WITHDRAW_BID_TYPEHASH, bidder, blockNumber, amount)
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != bidder) revert WrongSigner();

        address feeRecipient = auctionGuard.getFeeAddress();

        if (feeRecipient == address(0)) revert ZeroAddress();
        if (balances[bidder] < amount) revert NotEnoughFunds();

        // book keeping
        balances[bidder] -= amount;

        // send funds
        (bool success, bytes memory error) = feeRecipient.call{value: amount}(
            ""
        );
        if (!success) revert TransferError(error);

        emit Withdraw(bidder, feeRecipient, amount);

        return true;
    }
}
