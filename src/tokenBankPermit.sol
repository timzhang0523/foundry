// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";


contract tokenBankPermit {
    using SafeERC20 for IERC20;
    mapping(address=>mapping (address => uint256)) public balances;
    event Deposit(address indexed user, uint256 amount);
    IERC20 public token;

    constructor(address tokenAddress) {
        token = IERC20(tokenAddress);
    }

    function depositWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(address(token)).permit(msg.sender, address(this), amount, deadline, v, r, s);
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) public {
        require(balances[address(token)][msg.sender] >= amount, "Insufficient balance in the contract");
        bytes memory payload = abi.encodeWithSignature("transfer(address,uint256)", msg.sender,amount);
        (bool success, ) = address(token).call(payload);
        if(success){
            balances[address(token)][msg.sender] -= amount;
        }
        // require(token.balanceOf(address(this)) >= amount, "Insufficient balance");
        // token.transfer(msg.sender, amount);
        // IERC20(token).safeTransfer(msg.sender,amount);
    }
}
