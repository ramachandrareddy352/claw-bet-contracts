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

        address gameAddress = 0x18A181748cA82500090C96E2d2D7194bB3C2b16A;
        ClawBetGame game = ClawBetGame(payable(gameAddress));

        address betTokenAddr = game.betToken();
        bool isNative = (betTokenAddr == address(0));
        IERC20 token = isNative ? IERC20(address(0)) : IERC20(betTokenAddr);

        address user = msg.sender; // broadcaster = user placing bet

        uint256 index = 0; // smallest bet by default
        uint256 betAmount = game.betAmounts(index);

        uint256 feeBP = game.feeBP();
        uint256 fee = (betAmount * feeBP) / game.BP_DIVISOR();
        uint256 netAmount = betAmount - fee;

        console.log("========== PLACE BET - BEFORE ==========");
        console.log("User address:                  %s", user);
        console.log("Game address:                  %s", gameAddress);
        console.log("Bet token:                     %s (native? %s)", betTokenAddr, isNative);
        console.log("Selected bet amount (index %s): %s", index, betAmount);
        console.log("Fee BP:                        %s (fee = %s)", feeBP, fee);
        console.log("Net amount after fee:          %s", netAmount);

        if (isNative) {
            console.log("User native BNB balance before:    %s wei", user.balance);
            console.log("Game native BNB balance before:    %s wei", gameAddress.balance);
        } else {
            console.log("User token balance before:         %s", token.balanceOf(user));
            console.log("Game token balance before:         %s", token.balanceOf(gameAddress));
        }

        address linkAddr = game.i_linkAddress();
        IERC20 link = IERC20(linkAddr);
        console.log("LINK token address:            %s", linkAddr);
        console.log("User LINK balance before:      %s", link.balanceOf(user));
        console.log("Game LINK balance before:      %s", link.balanceOf(gameAddress));

        // If ERC20 token bet → approve
        if (!isNative) {
            token.approve(gameAddress, betAmount);
            console.log("Approved %s tokens for game", betAmount);
        }

        // Place the bet
        uint256 requestId;
        if (isNative) {
            requestId = game.placeBet{value: betAmount}(index);
        } else {
            requestId = game.placeBet(index);
        }

        console.log("========== PLACE BET - AFTER ==========");
        console.log("Bet placed! Request ID:        %s", requestId);

        if (isNative) {
            console.log("User native BNB balance after:     %s wei (change: -%s)", user.balance, betAmount);
            console.log("Game native BNB balance after:     %s wei (change: +%s)", gameAddress.balance, betAmount);
        } else {
            console.log("User token balance after:          %s (change: -%s)", token.balanceOf(user), betAmount);
            console.log("Game token balance after:          %s (change: +%s)", token.balanceOf(gameAddress), betAmount);
        }

        console.log("User LINK balance after:       %s", link.balanceOf(user));
        console.log("Game LINK balance after:       %s", link.balanceOf(gameAddress));

        console.log("Waiting for Chainlink fulfillment... Check in ~1-2 minutes");
        console.log("Use CheckBet script with requestId = %s", requestId);

        vm.stopBroadcast();
    }
}
