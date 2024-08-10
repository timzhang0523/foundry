// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AutoCollectUpKeep} from "../src/auto/AutoCollectUpKeep.sol";

contract AutoCollectUpKeepScript is Script {
    AutoCollectUpKeep public autoCollectUpKeep;
    address token = 0x7DdBAA3F8559ae453Ce00a8d5Ad94A9c2309bae1;
    address bank = 0xe99342Ba99c3286f9E89Bab1e565bF8c76D156E7;
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        new AutoCollectUpKeep(token,bank);
     
        vm.stopBroadcast();
    }
}
