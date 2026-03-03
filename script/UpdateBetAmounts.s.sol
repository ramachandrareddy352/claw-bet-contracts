// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/ClawBetGame.sol";

// forge script script/UpdateBetAmounts.s.sol:UpdateBetAmounts --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 --private-key $PRIVATE_KEY --broadcast

contract UpdateBetAmounts is Script {
    function run() external {
        vm.startBroadcast();

        address gameAddress = 0x18A181748cA82500090C96E2d2D7194bB3C2b16A;
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

/*
== Logs ==
  Bet amounts updated successfully
  ========== UPDATED BET AMOUNTS ==========
  Index 0 : 100000000000000000
  Index 1 : 1000000000000000000
  Index 2 : 2000000000000000000
  Index 3 : 5000000000000000000
  Index 4 : 10000000000000000000

## Setting up 1 EVM.

==========================

Chain 97

Estimated gas price: 0.1 gwei

Estimated total gas used for script: 54882

Estimated amount required: 0.0000054882 ETH

==========================

##### bsc-testnet
✅  [Success] Hash: 0x42560068f07f6d62633566c519e4937ea21b367128e71a957fd0e64cb3fc4879
Block: 93602141
Paid: 0.0000039734 ETH (39734 gas * 0.1 gwei)

✅ Sequence #1 on bsc-testnet | Total Paid: 0.0000039734 ETH (39734 gas * avg 0.1 gwei)                      

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: C:/Users/rcrta/OneDrive/Desktop/claw-game/claw-bet-game-contracts/broadcast\UpdateBetAmounts.s.sol\97\run-latest.json

Sensitive values saved to: C:/Users/rcrta/OneDrive/Desktop/claw-game/claw-bet-game-contracts/cache\UpdateBetAmounts.s.sol\97\run-latest.json
*/
