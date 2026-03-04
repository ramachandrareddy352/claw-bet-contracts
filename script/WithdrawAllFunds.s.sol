// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/ClawBetGame.sol";

// forge script script/WithdrawAllFunds.s.sol:WithdrawAllFunds --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 --private-key YOUR_PRIVATE_KEY --broadcast
// interface IERC20 {
//     function balanceOf(address account) external view returns (uint256);
// }

contract WithdrawAllFunds is Script {
    function run() external {
        address gameAddress = 0x5D55E23E6D9CEd6c2B9abBDfE5cEBAd1C4567333;

        // LINK token on BNB testnet
        address LINK = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;

        ClawBetGame game = ClawBetGame(payable(gameAddress));

        uint256 nativeBalance = gameAddress.balance;
        uint256 linkBalance = IERC20(LINK).balanceOf(gameAddress);

        console.log("=========== CONTRACT BALANCES ===========");
        console.log("Native BNB:", nativeBalance);
        console.log("LINK:", linkBalance);
        console.log("=========================================");

        vm.startBroadcast();

        if (nativeBalance > 0) {
            console.log("Withdrawing native BNB...");
            game.withdrawNative(msg.sender, nativeBalance);
        }

        if (linkBalance > 0) {
            console.log("Withdrawing LINK...");
            game.withdrawERC20(LINK, msg.sender, linkBalance);
        }

        vm.stopBroadcast();

        console.log("Withdrawal complete.");
    }
}
