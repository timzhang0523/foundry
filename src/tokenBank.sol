// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract tokenBank {
    using SafeERC20 for IERC20;
    mapping(address=>mapping (address => uint256)) public balances;
    event Deposit(address indexed user, uint256 amount);
    
    function deposit(IERC20 token,uint amount) external   {
        token.safeTransferFrom(msg.sender, address(this), amount);
        balances[address(token)][msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(address token,uint256 amount) public {
        require(balances[token][msg.sender] >= amount, "Insufficient balance in the contract");
        bytes memory payload = abi.encodeWithSignature("transfer(address,uint256)", msg.sender,amount);
        (bool success, ) = token.call(payload);
        if(success){
            balances[token][msg.sender] -= amount;
        }
        // IERC20(token).safeTransfer(msg.sender,amount);
    }
}