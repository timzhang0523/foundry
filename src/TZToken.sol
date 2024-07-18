// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TZToken is ERC20 {
    constructor() ERC20("TESTZ", "TZ") {
        _mint(msg.sender, 2e9 ether);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}
