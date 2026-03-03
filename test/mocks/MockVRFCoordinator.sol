// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract MockVRFCoordinator {
    uint256 public currentRequestId;
    mapping(uint256 => address) public consumers;

    /*//////////////////////////////////////////////////////////////
                        REQUEST RANDOM
    //////////////////////////////////////////////////////////////*/

    function requestRandomWords(bytes32, uint64, uint16, uint32, uint32) external returns (uint256 requestId) {
        currentRequestId++;
        requestId = currentRequestId;

        consumers[requestId] = msg.sender;

        console.log("========== VRF REQUEST ==========");
        console.log("Request ID:", requestId);
        console.log("Requester (Game Contract):", msg.sender);
        console.log("Stored consumer:", consumers[requestId]);
        console.log("=================================");

        return requestId;
    }

    /*//////////////////////////////////////////////////////////////
                        FULFILL RANDOM
    //////////////////////////////////////////////////////////////*/

    function fulfill(uint256 requestId) external {
        console.log("========== VRF FULFILL ==========");

        address consumer = consumers[requestId];

        console.log("Fulfill called by:", msg.sender);
        console.log("Request ID:", requestId);
        console.log("Stored consumer address:", consumer);

        require(consumer != address(0), "Invalid request");

        uint256 rnd = uint256(keccak256(abi.encodePacked(block.timestamp, block.number, requestId, uint256(123456))));

        console.log("Generated Random Number:", rnd);

        uint256[] memory words = new uint256[](1);
        words[0] = rnd;

        console.log("Calling rawFulfillRandomWords on consumer...");

        // 🔥 CORRECT CALL (IMPORTANT)
        VRFConsumerBaseV2(consumer).rawFulfillRandomWords(requestId, words);

        console.log("Fulfill completed successfully.");
        console.log("=================================");
    }
}
