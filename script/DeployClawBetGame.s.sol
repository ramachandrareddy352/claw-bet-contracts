// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ClawBetGame.sol";
// forge script script/DeployClawBetGame.s.sol:DeployClawBetGame  --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545  --private-key $PRIVATE_KEY --broadcast

// cast send 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06 "transfer(address,uint256)" 0x5D55E23E6D9CEd6c2B9abBDfE5cEBAd1C4567333 5000000000000000000 --rpc-url https://data-seed-prebsc-1-s1.bnbchain.org:8545 --private-key $PRIVATE_KEY

contract DeployClawBetGame is Script {
    function run() external {
        vm.startBroadcast();

        // ===== Chainlink VRF v2.5 Direct Funding Config for BNB Chain Testnet =====
        address vrfWrapper = 0x471506e6ADED0b9811D05B8cAc8Db25eE839Ac94; // VRFV2PlusWrapper

        // You might want to set the owner to your deployer or a multisig
        address clawOwner = msg.sender;

        // betToken = address(0) means native BNB bets (change to ERC20 if needed)
        address betToken = 0xdF81f07910b533bC6899441aD131c5a08a4C6BfA; // use link token

        // Deploy the game contract
        ClawBetGame game = new ClawBetGame(vrfWrapper, clawOwner, betToken);

        console.log("ClawBetGame deployed at: %s", address(game));
        console.log("VRF Wrapper used:        %s", vrfWrapper);
        console.log("Owner / Claw Owner:      %s", clawOwner);
        vm.stopBroadcast();
    }
}

/*

== Logs ==
  ClawBetGame deployed at: 0x5D55E23E6D9CEd6c2B9abBDfE5cEBAd1C4567333
  VRF Wrapper used:        0x471506e6ADED0b9811D05B8cAc8Db25eE839Ac94
  LINK Token:              0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06
  Owner / Claw Owner:      0x4319f90913bf7dC168887d45f3bfDD9a2C5C9291

## Setting up 1 EVM.

==========================

Chain 97

Estimated gas price: 0.1 gwei

Estimated total gas used for script: 6211043

Estimated amount required: 0.0006211043 ETH

==========================

##### bsc-testnet
✅  [Success] Hash: 0x9d5ac68c625df6bbac41a68f54f43f9fe7ae0c6d65ff283e31dc2875cfc05c6e
Contract Address: 0x5D55E23E6D9CEd6c2B9abBDfE5cEBAd1C4567333
Block: 93601630
Paid: 0.0004777726 ETH (4777726 gas * 0.1 gwei)

✅ Sequence #1 on bsc-testnet | Total Paid: 0.0004777726 ETH (4777726 gas * avg 0.1 gwei)


==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: C:/Users/rcrta/OneDrive/Desktop/claw-game/claw-bet-game-contracts\broadcast\DeployClawBetGame.s.sol\97\run-latest.json

Sensitive values saved to: C:/Users/rcrta/OneDrive/Desktop/claw-game/claw-bet-game-contracts/cache\DeployClawBetGame.s.sol\97\run-latest.json
*/
