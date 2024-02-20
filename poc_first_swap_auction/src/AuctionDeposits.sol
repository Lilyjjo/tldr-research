pragma solidity ^0.8;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
// TODO check if any issues in using older verion of EIP712 OZ contract
import {EIP712} from "openzeppelin-contracts/utils/cryptography/draft-EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {IAuctionGuard} from "./IAuctionGuard.sol";
import {IAuctionDeposits} from "./IAuctionDeposits.sol";

contract AuctionDeposits is Ownable, EIP712, IAuctionDeposits {
    IAuctionGuard public auction;

    mapping(address => uint256) public balances;
    uint256 public lastAuction;

    // Hash of the bid type for EIP-712 compliance.
    bytes32 public constant WITHDRAW_BID_TYPEHASH =
        keccak256(
            "withdrawBid(address bidder,uint256 blockNumber,uint256 amount)"
        );

    error OnlyAuction();
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

    constructor(IAuctionGuard auction_) Ownable() EIP712("AuctionDeposits", "v1") {
       auction = auction_; 
    }

    modifier onlyAuction() {
        if (msg.sender != address(auction)) revert OnlyAuction();
        _;
    }

    function deposit() payable external {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.sender, msg.value);
    }

    function balanceOf(address user) external view returns(uint256) {
        return balances[user];
    }

    function withdraw(address to, uint256 amount) external {
        // check if auction ongoing
        if(!auction.currentBlockAuctionDone()) {
            revert AuctionNotDone();
        }

        // checks
        if(to == address(0)) revert ZeroAddress();
        if(balances[msg.sender] < amount) revert NotEnoughFunds();

        // book keeping
        balances[msg.sender] -= amount;

        // send funds
        (bool success, bytes memory error) = to.call{value:amount}("");
        if (!success) revert TransferError(error);

        emit Withdraw(msg.sender, to, amount);
    }

    function withdrawBid(
        address bidder,
        uint256 blockNumber, 
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyAuction returns (bool) {
        if(blockNumber != block.number) revert WrongBlockNumber(); 
        if(lastAuction == block.number) revert AuctionAlreadyWithdrawn();
        lastAuction = block.number;

        bytes32 structHash = keccak256(
            abi.encode(
                WITHDRAW_BID_TYPEHASH,
                bidder,
                amount
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != bidder) revert WrongSigner();

        address feeRecipient = auction.getFeeAddress();

        if(feeRecipient == address(0)) revert ZeroAddress();
        if(balances[bidder] < amount) revert NotEnoughFunds(); 

        // book keeping
        balances[bidder] -= amount;

        // send funds
        (bool success, bytes memory error) = feeRecipient.call{value:amount}("");
        if (!success) revert TransferError(error);

        emit Withdraw(bidder, feeRecipient, amount);

        return true;
    }
}
