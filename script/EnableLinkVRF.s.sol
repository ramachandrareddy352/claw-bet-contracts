// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ClawBetGame.sol";

// forge script script/EnableLinkVRF.s.sol:EnableLinkVRF --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 --private-key YOUR_PRIVATE_KEY --broadcast
contract EnableLinkVRF is Script {
    function run() external {
        // Replace with your deployed contract
        address clawBetGame = 0x5D55E23E6D9CEd6c2B9abBDfE5cEBAd1C4567333;

        vm.startBroadcast();

        ClawBetGame game = ClawBetGame(payable(clawBetGame));

        // callbackGasLimit, confirmations, enableNativePayment
        game.updateVRF(
            300000, // gas limit
            3, // confirmations
            true // FALSE = use LINK for VRF, TRUE = use Native
        );

        vm.stopBroadcast();
    }
}
