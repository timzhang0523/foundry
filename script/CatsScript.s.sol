// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CatsToken} from "../src/auto/CatsToken.sol";

contract CatsScript is Script {
    CatsToken public token;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        token = new CatsToken();
        // console.log(token);

        vm.stopBroadcast();
    }
}
