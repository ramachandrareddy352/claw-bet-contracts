// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ClawBetGame.sol";
// forge script scripts/DeployClawBetGame.s.sol:DeployClawBetGame  --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545  --private-key $PRIVATE_KEY --broadcast

// cast send 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06 "transfer(address,uint256)" 0xf316b4698b1D147Ac0a6B0E63A7E012070b89CE0 10000000000000000000 --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 --private-key $PRIVATE_KEY

contract DeployClawBetGame is Script {
    function run() external {
        vm.startBroadcast();

        // ===== Chainlink VRF Config for BNB testnet =====
        address vrfCoordinator = 0xDA3b641D438362C440Ac5458c57e00a712b66700;
        uint256 subscriptionId = 25998941021040969888642062667829070948263091917545316489339551033581459386854; // ← Replace with your actual subscription ID
        bytes32 keyHash = 0x8596b430971ac45bdf6088665b9ad8e8630c9d5049ab54b14dff711bee7c0e26; // Example
        // LINK Token => 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06

        // You might want to set the owner to your deployer
        address owner = msg.sender;

        // Deploy the contract
        ClawBetGame game = new ClawBetGame(
            vrfCoordinator, subscriptionId, keyHash, owner, address(0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06)
        );

        console.log("ClawBetGame deployed at:", address(game));

        vm.stopBroadcast();
    }
}

/*

== Logs ==
  ClawBetGame deployed at: 0xf316b4698b1D147Ac0a6B0E63A7E012070b89CE0

## Setting up 1 EVM.

==========================

Chain 97

Estimated gas price: 0.1 gwei

Estimated total gas used for script: 5498483

Estimated amount required: 0.0005498483 ETH

==========================

##### bsc-testnet
✅  [Success] Hash: 0x9c704a971b715902b218abfc14b9d33b039640ee27fda62884ea271ce5923067
Contract Address: 0xf316b4698b1D147Ac0a6B0E63A7E012070b89CE0
Block: 93546813
Paid: 0.0004229603 ETH (4229603 gas * 0.1 gwei)

✅ Sequence #1 on bsc-testnet | Total Paid: 0.0004229603 ETH (4229603 gas * avg 0.1 gwei)             
                                                                                                      
                                                                                                      
==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: C:/Users/rcrta/OneDrive/Desktop/claw-game/claw-bet-game-contracts\broadcast\DeployClawBetGame.s.sol\97\run-latest.json

Sensitive values saved to: C:/Users/rcrta/OneDrive/Desktop/claw-game/claw-bet-game-contracts/cache\DeployClawBetGame.s.sol\97\run-latest.json

*/
