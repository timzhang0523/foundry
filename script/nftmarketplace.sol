// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/nftMarketplace.sol";

contract DeployToken is Script {
    function run() external {
        vm.startBroadcast();
        new NFTMarket();
        vm.stopBroadcast();
    }
}

