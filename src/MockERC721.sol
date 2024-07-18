// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Mock is ERC721 {
    uint256 private _tokenIdCounter;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to) public returns (uint256) {
        _tokenIdCounter++;
        _mint(to, _tokenIdCounter);
        return _tokenIdCounter;
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }
}
