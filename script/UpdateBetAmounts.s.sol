// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/ClawBetGame.sol";

// forge script script/UpdateBetAmounts.s.sol:UpdateBetAmounts --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 --private-key $PRIVATE_KEY --broadcast

contract UpdateBetAmounts is Script {
    function run() external {
        vm.startBroadcast();

        address gameAddress = 0xf316b4698b1D147Ac0a6B0E63A7E012070b89CE0;
        ClawBetGame game = ClawBetGame(payable(gameAddress));

        uint256[] memory newAmounts = new uint256[](5);
        newAmounts[0] = 0.1 ether;
        newAmounts[1] = 1 ether;
        newAmounts[2] = 2 ether;
        newAmounts[3] = 5 ether;
        newAmounts[4] = 10 ether;

        game.setBetAmounts(newAmounts);

        console.log("Bet amounts updated successfully");

        console.log("========== UPDATED BET AMOUNTS ==========");

        for (uint256 i = 0; i < 5; i++) {
            uint256 amount = game.betAmounts(i);
            console.log("Index", i, ":", amount);
        }

        vm.stopBroadcast();
    }
}
