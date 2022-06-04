//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "utils/contracts/payments/Fees.sol";
import "utils/contracts/payments/ERC20Payments.sol";

interface IAuctions {

    struct Bid {
        address bidder;
        uint bid;
    }

    struct Auction {
        uint tokenId;
        address seller;
        uint startingBid;
        Bid[] bids;
        uint endsAt;
        bool active;
    }

    event FeesTaken(uint fees);
    event FeesSplit(uint fees);
    event FeeSet(Fees.Fee fee);

    event MinBidIncrementSet(uint minBidIncrement);

    event AuctionStarted(uint auctionId, address seller, uint tokenId, uint startingBid, uint endsAt);
    event BidOn(uint auctionId, uint bidId, address bidder, uint bid);
    event AuctionCancelled(uint auctionId);
    event AuctionEnded(uint auctionId, uint bidId);

    function setFee(Fees.Fee calldata fee) external;

    function splitFees() external;

    function setMinBidIncrement(uint minBidIncrement) external;

    function createAuction(uint tokenId, uint startingBid, uint endsAt) external;

    function makeBid(uint auctionId, uint bid) external;

    function endAuction(uint auctionId) external;

}

contract Auctions is IAuctions, Ownable, ERC20Payments, ReentrancyGuard, ERC721Holder {

    using SafeERC20 for IERC20;
    using Fees for uint;

    IERC721 private _lambos;
    IERC20 private _hville;

    constructor(IERC721 lambos, IERC20 hville) ERC20Payments(hville) {
        _lambos = lambos;
        _hville = hville;
    }

    Fees.Fee private _fee;
    uint private _fees;
    uint private _minBidIncrement;

    function setFee(Fees.Fee calldata fee) external override nonReentrant onlyOwner {
        _fee = fee;
        emit FeeSet(fee);
    }

    function splitFees() external override nonReentrant {
        uint fees = _fees;
        require(_makePayment(fees), "No payees set up.");
        delete _fees;
        emit FeesSplit(fees);
    }

    function setMinBidIncrement(uint minBidIncrement) external override nonReentrant onlyOwner {
        _minBidIncrement = minBidIncrement;
        emit MinBidIncrementSet(minBidIncrement);
    }

    Auction[] private _auctions;

    function createAuction(uint tokenId, uint startingBid, uint endsAt) external override nonReentrant {
        address seller = msg.sender;
        uint auctionId = _auctions.length;
        _lambos.safeTransferFrom(msg.sender, address(this), tokenId);
        _auctions.push();
        Auction storage auction = _auctions[auctionId];
        auction.tokenId = tokenId;
        auction.seller = seller;
        auction.startingBid = startingBid;
        auction.endsAt = endsAt;
        auction.active = true;
        emit AuctionStarted(auctionId, seller, tokenId,startingBid,endsAt);
    }

    function makeBid(uint auctionId, uint bid) external override nonReentrant {
        Auction storage auction = _auctions[auctionId];
        require(block.timestamp < auction.endsAt, "Acution has ended.");
        Bid[] storage bids = auction.bids;
        uint bidId = bids.length;

        if(bidId > 0) {
            Bid storage previousBid = bids[bidId - 1];
            _hville.safeTransfer(previousBid.bidder, previousBid.bid);
            require(bid >= previousBid.bid + _minBidIncrement, "Bid does not increase on the previous bid enough.");
        } else {
            require(bid >= auction.startingBid, "Bid must match the starting bid.");
        }

        address bidder = msg.sender;

        _hville.safeTransferFrom(bidder, address(this), bid);

        Bid memory newBid = Bid(
            {
                bidder: bidder,
                bid: bid
            }
        );

        bids.push(newBid);
        emit BidOn(auctionId,bidId,bidder,bid);
    }

    function endAuction(uint auctionId) external override nonReentrant {
        Auction storage auction = _auctions[auctionId];
        bool ended = block.timestamp >= auction.endsAt;
        require(auction.active, "Auction is not active.");
        Bid[] storage bids = auction.bids;
        if(bids.length == 0) {
            if(!ended) {
                require(msg.sender == auction.seller, "You are not the seller of this auction.");
            }
            auction.active = false;
            emit AuctionCancelled(auctionId);
        } else {
            require(ended, "Auction has not ended yet.");
            uint bidId = bids.length - 1;
            Bid storage winningBid = bids[bidId];
            uint fees = winningBid.bid.feesOf(_fee);
            _fees += fees;
            _hville.safeTransfer(auction.seller, winningBid.bid);
            _lambos.safeTransferFrom(address(this), auction.seller, auction.tokenId);
            emit AuctionEnded(auctionId, bidId);
            emit FeesTaken(fees);
        }
    }
}