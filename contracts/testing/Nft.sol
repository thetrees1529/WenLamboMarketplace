//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Nft is ERC721Enumerable {
    constructor() ERC721("Test NFT", "TNFT") {}
    function mintToMe(uint tokenId) external {
        _mint(msg.sender, tokenId);
    }
}