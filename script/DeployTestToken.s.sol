// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/TestToken.sol";

// forge script script/DeployTestToken.s.sol:DeployTestToken --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 --private-key YOUR_PRIVATE_KEY --broadcast
contract DeployTestToken is Script {
    function run() external {
        // Address that receives 1M tokens
        address receiver = msg.sender;

        vm.startBroadcast();

        TestToken token = new TestToken(receiver);

        console.log("TestToken deployed at:", address(token));
        console.log("1,000,000 tokens minted to:", receiver);

        vm.stopBroadcast();
    }
}
