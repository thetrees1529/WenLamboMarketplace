//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Fees.sol";
import "./ERC20Payments.sol";

interface IOffers {

    struct Nft {
        IERC721 nft;
        uint id;
    }

    struct Offer {
        address buyer;
        uint tokenId;
        uint hville;
        Nft[] nfts;
        uint expiresAt;
        bool active;
    }

    event FeesTaken(uint fees);
    event FeesSplit(uint fees);
    event FeeSet(Fees.Fee fee);

    event Offered(uint offerId, address buyer, uint tokenId, uint hville, Nft[] nfts, uint expiresAt);
    event OfferCancelled(uint offerId);
    event OfferAccepted(uint offerId, address seller);

    function setFee(Fees.Fee calldata fee) external;

    function splitFees() external;

    function makeOffer(uint tokenId, uint hville, Nft[] calldata nfts, uint expiresAt) external;

    function acceptOffer(uint offerId) external;

    function cancelOffer(uint offerId) external;

}

contract Offers is IOffers, Ownable, ERC20Payments, ReentrancyGuard {

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

    Offer[] private _offers;

    function makeOffer(uint tokenId, uint hville, Nft[] calldata nfts, uint expiresAt) external override nonReentrant {
        address buyer = msg.sender;
        uint offerId = _offers.length;
        _offers.push();
        Offer storage offer = _offers[offerId];
        offer.buyer= buyer;
        offer.tokenId= tokenId;
        offer.hville= hville;
        offer.expiresAt = expiresAt;
        for(uint i; i < nfts.length; i ++) {
            offer.nfts.push(nfts[i]);
        }
        offer.active= true;
        emit Offered(offerId, buyer, tokenId, hville, nfts, expiresAt);
    }

    function acceptOffer(uint offerId) external override nonReentrant {
        address seller = msg.sender;
        Offer storage offer = _offers[offerId];
        require(offer.active, "This offer is not active.");
        require(block.timestamp < offer.expiresAt, "Offer has expired.");
        _lambos.safeTransferFrom(seller, offer.buyer, offer.tokenId);
        uint fees = offer.hville.feesOf(_fee);
        _fees += fees;
        uint toSeller = offer.hville - fees;
        _hville.safeTransferFrom(offer.buyer, seller, toSeller);
        _hville.safeTransferFrom(offer.buyer, address(this), fees);
        Nft[] storage nfts = offer.nfts;
        for(uint i; i < nfts.length; i ++) {
            Nft storage nft = nfts[i];
            nft.nft.safeTransferFrom(offer.buyer, seller, nft.id);
        }
        emit FeesTaken(fees);
        emit OfferAccepted(offerId, seller);
    }

    function cancelOffer(uint offerId) external override nonReentrant {
        Offer storage offer = _offers[offerId];
        require(msg.sender == offer.buyer, "You didn't make this offer.");
        require(offer.active, "This offer is not active.");
        offer.active = false;
        emit OfferCancelled(offerId);
    }

}