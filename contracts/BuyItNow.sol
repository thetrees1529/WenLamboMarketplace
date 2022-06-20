//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "utils/contracts/payments/Fees.sol";
import "utils/contracts/payments/ERC20Payments.sol";

interface IBuyItNow {
    event Listed(uint listingId, address seller, uint tokenId, uint price, uint expiresAt);
    event Sold(uint listingId, uint feesTaken, address buyer);
    event Cancelled(uint listingId);
    event PriceEdited(uint listingId, uint newPrice);
    event FeeSet(Fees.Fee fee);
    function setFee(Fees.Fee calldata fee) external;
    function withdraw() external;
    function list(uint tokenId, uint price, uint expiresAt) external;
    function purchase(uint listingId, uint expectedPrice) external;
    function editPrice(uint listingId, uint newPrice) external;
    function cancel(uint listingId) external;
}

contract BuyItNow is IBuyItNow, Ownable, ERC20Payments, ERC721Holder, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using Fees for uint;

    IERC721 private _lambos;
    IERC20 private _hville;

    constructor(IERC721 lambos, IERC20 hville) ERC20Payments(hville) {
        _lambos = lambos;
        _hville = hville;
    }

    struct Listing {
        uint tokenId;
        uint price;
        uint expiresAt;
        address seller;
        bool active;
    }

    Listing[] private _listings;
    Fees.Fee private _fee;
    uint private _fees;

    function setFee(Fees.Fee calldata fee) external override nonReentrant onlyOwner {
        _fee = fee;
        emit FeeSet(fee);
    }

    function withdraw() external override nonReentrant {
        uint fees = _fees;
        _hville.safeTransfer(msg.sender, fees);
        delete _fees;
    }

    function list(uint tokenId, uint price, uint expiresAt) external override nonReentrant {
        _lambos.safeTransferFrom(msg.sender, address(this), tokenId);
        address seller = msg.sender;
        uint listingId = _listings.length;
        _listings.push(
            Listing(
                {
                    tokenId: tokenId,
                    price: price,
                    expiresAt: expiresAt,
                    seller: seller,
                    active: true
                }
            )
        );
        emit Listed(listingId, seller, tokenId, price, expiresAt);
    }

    function purchase(uint listingId, uint expectedPrice) external override nonReentrant {
        address buyer = msg.sender;
        Listing storage listing = _listings[listingId];
        require(listing.active, "Cannot purchase inactive listing.");
        require(listing.price == expectedPrice, "Price has changed.");
        require(block.timestamp < listing.expiresAt, "Listing has expired.");
        uint fees = listing.price.feesOf(_fee);
        uint toSeller = listing.price - fees;
        _hville.safeTransferFrom(buyer, listing.seller, toSeller);
        _hville.safeTransferFrom(buyer, address(this), fees);
        _lambos.safeTransferFrom(address(this), buyer, listing.tokenId);
        listing.active = false;

        if(!_makePayment(fees)) _fees += fees;

        emit Sold(listingId, fees, buyer);
    }

    function editPrice(uint listingId, uint newPrice) external override nonReentrant {
        Listing storage listing = _listings[listingId];
        require(listing.active, "Cannot edit price of listing that is not active.");
        require(block.timestamp < listing.expiresAt, "Listing has expired.");
        require(msg.sender == listing.seller, "Cannot edit the price of a listing you aren't the seller of.");
        listing.price = newPrice;
        emit PriceEdited(listingId, newPrice);
    }

    function cancel(uint listingId) external override nonReentrant {
        Listing storage listing = _listings[listingId];
        require(listing.active, "Cannot cancel listing that is not active.");
        require(msg.sender == listing.seller, "Cannot cancel listing you aren't the seller of.");
        _lambos.safeTransferFrom(address(this), msg.sender, listing.tokenId);
        listing.active = false;
        emit Cancelled(listingId);
    }

}