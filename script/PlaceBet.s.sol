// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/ClawBetGame.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// forge script script/PlaceBet.s.sol:PlaceBet --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 --private-key $PRIVATE_KEY --broadcast

contract PlaceBet is Script {
    function run() external {
        vm.startBroadcast();

        address gameAddress = 0xf316b4698b1D147Ac0a6B0E63A7E012070b89CE0;
        ClawBetGame game = ClawBetGame(payable(gameAddress));

        address tokenAddress = game.betToken();
        IERC20 token = IERC20(tokenAddress);

        uint256 betAmount = game.betAmounts(0); // index 0 = 1 token

        console.log("========== PLACING BET ==========");
        console.log("Game Address:", gameAddress);
        console.log("Token Address:", tokenAddress);
        console.log("Bet Amount:", betAmount);

        // Approve tokens
        token.approve(gameAddress, betAmount);
        console.log("Approved tokens");

        // Place bet
        uint256 requestId = game.placeBet(0);
        console.log("Bet placed. Request ID:", requestId);

        vm.stopBroadcast();
    }
}
