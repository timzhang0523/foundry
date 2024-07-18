// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract ZLERC20Permit is ERC20, ERC20Permit {
    constructor() ERC20("ZLToken", "MTK") ERC20Permit("ZLToken") {
        _mint(msg.sender, 10000000000 * 10 ** 18);
    }
}
