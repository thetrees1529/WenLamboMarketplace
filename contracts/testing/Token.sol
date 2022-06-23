//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20("Test token", "TST") {
    function mintToMe(uint tokenId) external {
        _mint(msg.sender, tokenId);
    }
}