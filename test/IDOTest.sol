// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test,Vm,console} from "forge-std/Test.sol";

import {ZLERC20Permit} from  "../src/ZLERC20Permit.sol";
import {IDO} from "../src/IDO.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IDOEvent{
    event Presale(address user,uint256 amount);
    event Claim(address user,uint256 amount);
    event Refund(address user,uint256 amount);
    event Withdraw(address user,uint256 amount);
}

contract IDOTest is Test,IDOEvent {
    using ECDSA for bytes32;
    address user;
    address admin;
    IDO public ido;
    ZLERC20Permit public token ;
    function setUp() public {
        user = makeAddr("user");
        admin = makeAddr("admin");
        // vm.startPrank("admin");
        token = new ZLERC20Permit();
        vm.prank(admin);
        ido = new IDO(address(token));
        // vm.stopPrank();
        // deal(address(token),address(ido), 1e6 ether);
    }

    function testIDOPresale() public payable {
        address randomUser = vm.addr(
            uint256(keccak256(abi.encodePacked("randomUser", block.timestamp)))
        );
        uint256 amount = 1 ether;
        vm.deal(randomUser, amount);

        deal(address(token),address(ido), 1_000_000 ether);

        assertEq(token.balanceOf(address(ido)),1e6 ether,"IDO: token is not ready~");
        // uint amount = msg.value;
        // vm.assume(msg.value > 0 && _price < 1e9 ether);
        // vm.assume(msg.value >= 0.0001 ether);
        vm.expectEmit(true, true, false, false);
        emit Presale(randomUser, amount);
        vm.prank(randomUser);
        ido.presale{value:amount}();
        assertEq(address(ido).balance, amount,"ido's balance eth mismatch!");
        assertEq(randomUser.balance, 0);
        assertEq(ido.balances(randomUser), amount);
    }

    function testClaim() public {
        address randomUser = vm.addr(
            uint256(keccak256(abi.encodePacked("randomUser", block.timestamp)))
        );
        uint256 amount = 150 ether;
        vm.deal(randomUser, amount);
        deal(address(token),address(ido), 1_000_000 ether);
        deal(address(ido), 200 ether);
        
        ido.presale{value:amount}();
        vm.warp(1724501408); // 设置超过31 天的时间戳
        uint256 tokenAmount = ido.balances(randomUser) *  token.balanceOf(address(ido)) / ido.poolEthAmount();
        vm.expectEmit(true, true, false, false);
        emit Claim(randomUser, tokenAmount);
        vm.prank(randomUser);
        ido.claim();
        assertEq(token.balanceOf(address(ido)), token.balanceOf(address(ido)) - tokenAmount,"ido's balance eth mismatch!");
        assertEq(token.balanceOf(address(randomUser)), tokenAmount);
    }

    function testRefund() public {
        address randomUser = vm.addr(
            uint256(keccak256(abi.encodePacked("randomUser", block.timestamp)))
        );
        uint256 amount = 20 ether;
        vm.deal(randomUser, amount);
        deal(address(token),address(ido), 1_000_000 ether);
        deal(address(ido), 200 ether);
        
        ido.presale{value:amount}();
        vm.warp(1724501408); // 设置超过31 天的时间戳
        uint256 _amount = ido.balances(randomUser);
        vm.expectEmit(true, true, false, false);
        emit Refund(randomUser, _amount);
        vm.prank(randomUser);
        ido.refund();
        assertEq(address(ido).balance,address(ido).balance - _amount,"ido's balance eth mismatch!");
        assertEq(ido.balances(randomUser), 0);
    }

    function testWithdraw() public {
        address randomUser = vm.addr(
            uint256(keccak256(abi.encodePacked("randomUser", block.timestamp)))
        );
        uint256 amount = 130 ether;
        vm.deal(randomUser, amount);
        deal(address(token),address(ido), 1_000_000 ether);
        deal(address(ido), 200 ether);
        
        ido.presale{value:amount}();
        vm.warp(1724501408); // 设置超过31 天的时间戳
        vm.expectEmit(true, true, false, false);
        emit Withdraw(admin, address(ido).balance);
        vm.prank(admin);
        ido.withdraw();
        assertEq(address(ido).balance,0,"ido's balance eth mismatch!");
    }




}
