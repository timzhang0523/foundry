// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Bank} from "../src/auto/Bank.sol";

contract BankScript is Script {
    Bank public bank;
    address token = 0x7DdBAA3F8559ae453Ce00a8d5Ad94A9c2309bae1;
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        new Bank(token);
        vm.stopBroadcast();
    }
}
