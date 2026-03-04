// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// forge script script/UpdateBetToken.s.sol:UpdateBetToken --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 --private-key YOUR_PRIVATE_KEY --broadcast

interface IClawBetGame {
    function setBetToken(address _token) external;
}

contract UpdateBetToken is Script {
    address constant GAME_CONTRACT = 0x5D55E23E6D9CEd6c2B9abBDfE5cEBAd1C4567333;
    address constant NEW_BET_TOKEN = 0x0cb3246Ec8451b708612f9e3e44B8816b82FCcD5;

    function run() external {
        vm.startBroadcast();

        IClawBetGame(payable(GAME_CONTRACT)).setBetToken(NEW_BET_TOKEN);

        vm.stopBroadcast();

        console.log("Bet token updated to:", NEW_BET_TOKEN);
    }
}
