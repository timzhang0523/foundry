//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract CatsToken is ERC20Permit {

    constructor() ERC20("Cats", "CatsT") ERC20Permit("Cats") {
        _mint(msg.sender, 1000000000 * 10 ** 18);
    }

}