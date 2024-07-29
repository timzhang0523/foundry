// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract BaseToken is ERC20, Ownable {
    uint256 public totalSupplyLimit;
    uint256 public perMintAmount;
    bool private initialized;

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        totalSupplyLimit = totalSupply;
        perMintAmount = perMint;
        _mint(owner, 0);
    }


    function mint(address to) external {
        require(totalSupply() + perMintAmount <= totalSupplyLimit, "Exceeds total supply limit");
        _mint(to, perMintAmount);
    }
}

contract FactoryV1 {
    event InscriptionDeployed(address indexed tokenAddress, string symbol, uint256 totalSupply, uint256 perMint);
    struct TokenInfo {
        address tokenAddress;
        uint256 perMintAmount;
    }
    mapping(address => TokenInfo) public inscriptions;

    function deployInscription(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        address owner
    ) public {
        BaseToken token = new BaseToken(name, symbol, totalSupply, perMint, owner);
        token.transferOwnership(msg.sender);
        inscriptions[address(token)] = TokenInfo(address(token), perMint);
        emit InscriptionDeployed(address(token), symbol, totalSupply, perMint);
    }

    function mintInscription(address tokenAddr) public {
        TokenInfo memory tokenInfo = inscriptions[tokenAddr];
        require(tokenInfo.tokenAddress != address(0), "Token not found");
        BaseToken(tokenInfo.tokenAddress).mint(msg.sender);
    }
}

