// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyToken.sol";

contract DeployToken is Script {
    function run() external {
        vm.startBroadcast();
        new MyToken("ZLLToken", "LLLMTK");
        vm.stopBroadcast();
    }
}

