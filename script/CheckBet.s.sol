// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// forge script script/CheckBet.s.sol:CheckBet --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545
interface IClawBetGame {
    function bets(uint256 requestId)
        external
        view
        returns (address player, bool settled, uint64 timestamp, uint256 amount, uint256 payout, uint256 paid);
}

contract CheckBet is Script {
    // Game contract address
    address GAME = 0x5D55E23E6D9CEd6c2B9abBDfE5cEBAd1C4567333;

    // Paste your requestId here
    uint256 REQUEST_ID = 80978038076649112390997737396183490728559263411613605458498538071169485367223;
    // 5000000000000000

    function run() external view {
        console.log("========== BET INFO ==========");

        (address player, bool settled, uint64 timestamp, uint256 amount, uint256 payout, uint256 paid) =
            IClawBetGame(payable(GAME)).bets(REQUEST_ID);

        console.log("Request ID:");
        console.logUint(REQUEST_ID);

        console.log("Player:");
        console.logAddress(player);

        console.log("Settled:");
        console.logBool(settled);

        console.log("Timestamp:");
        console.logUint(timestamp);

        console.log("Amount:");
        console.logUint(amount);

        console.log("Payout:");
        console.logUint(payout);

        console.log("VRF Paid:");
        console.logUint(paid);

        console.log("================================");
    }
}
