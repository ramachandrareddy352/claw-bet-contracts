// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/ClawBetGame.sol";

// forge script script/ReadClawBetGame.s.sol:ReadClawBetGame --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545

contract ReadClawBetGame is Script {
    function run() external view {
        address deployedAddress = 0x18A181748cA82500090C96E2d2D7194bB3C2b16A;

        ClawBetGame game = ClawBetGame(payable(deployedAddress));

        console.log("========== CLAW BET GAME STORAGE ==========");
        console.log("Contract Address:", deployedAddress);

        console.log("Claw Owner:", game.clawOwner());
        console.log("Bet Token:", game.betToken());
        console.log("Fee BP:", game.feeBP());
        console.log("Total Weight:", game.totalWeight());

        console.log("Callback Gas Limit:", game.callbackGasLimit());
        console.log("Request Confirmations:", game.requestConfirmations());
        console.log("Enable Native Payment:", game.enableNativePayment());

        console.log("---------- Default Bet Amounts ----------");
        for (uint256 i = 0; i < 5; i++) {
            console.log("Bet Amount Index", i, game.betAmounts(i));
        }

        console.log("---------- First 5 Multipliers ----------");
        for (uint256 i = 0; i < 5; i++) {
            console.log("Multiplier Index", i, game.multipliers(i));
        }

        console.log("=========================================");
    }
}
