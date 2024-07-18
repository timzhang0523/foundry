// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test,Vm,console} from "forge-std/Test.sol";

import {ZLERC20Permit} from  "../src/ZLERC20Permit.sol";
import {tokenBankPermit} from "../src/tokenBankPermit.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IbankEvent{
    event Deposit(address indexed user, uint amount);
}

contract bankPermitTest is Test,IbankEvent {
    using ECDSA for bytes32;

    tokenBankPermit public bank;
    ZLERC20Permit public token ;
    function setUp() public {
        token = new ZLERC20Permit();
        bank = new tokenBankPermit(address(token));
    }

    function testDepositWithPermit() public {
        
        (address alice,uint256 privateKey) = makeAddrAndKey("alice");
        uint256 amount = 1000 ;
        deal(address(token),alice, 1e6 ether);
        uint256 nonce = token.nonces(alice);
        uint256 deadline = block.timestamp + 2 hours;
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                alice,
                address(bank),
                amount,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                structHash
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        vm.startPrank(alice);
        vm.expectEmit(true, true, false, false);
        emit Deposit(alice, amount);
        bank.depositWithPermit(amount, deadline, v, r, s);
        vm.stopPrank();
        assertEq(token.balanceOf(address(bank)), amount);
        assertEq(token.nonces(alice), 1);

    }

}
