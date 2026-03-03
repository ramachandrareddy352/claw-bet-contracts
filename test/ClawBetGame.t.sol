// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../src/ClawBetGame.sol";
import "./mocks/MockVRFCoordinator.sol";
import "./mocks/MockERC20.sol";

contract ClawBetGameTest is Test {
    ClawBetGame game;
    MockVRFCoordinator mockVRF;
    MockERC20 mockToken;

    address player = address(1);

    function setUp() public {
        mockVRF = new MockVRFCoordinator();

        game = new ClawBetGame(address(mockVRF), 1, bytes32("keyhash"), address(this), address(0));

        mockToken = new MockERC20();

        vm.deal(address(game), 1000 ether); // add liquidity to game and link tokens also
        vm.deal(player, 100 ether);
    }

    // NATIVE BET TESTS, IMP: uncomment the delete bets[requestId]; to see the consoles correctely
    function testResolveNativeBet() public {
        console.log("----------- START NATIVE BET TEST -----------");

        uint256 playerBalanceBefore = player.balance;
        uint256 contractBalanceBefore = address(game).balance;

        console.log("Player balance BEFORE:", playerBalanceBefore);
        console.log("Contract balance BEFORE:", contractBalanceBefore);

        vm.prank(player);
        uint256 requestId = game.placeBet{value: 1 ether}(0);

        console.log("Request ID:", requestId);

        uint256 contractBalanceAfterBet = address(game).balance;
        console.log("Contract balance AFTER BET:", contractBalanceAfterBet);

        // Trigger VRF
        mockVRF.fulfill(requestId);

        (address bettor, uint256 amount,, bool settled) = game.bets(requestId);

        console.log("Bet amount:", amount);
        console.log("Settled:", settled);

        uint256 fee = (amount * game.feeBP()) / 10000;
        uint256 net = amount - fee;

        console.log("Fee:", fee);
        console.log("Net amount:", net);

        // Calculate payout manually for debug
        uint256 totalWeight = game.totalWeight();
        console.log("Total Weight:", totalWeight);

        uint256 playerBalanceAfter = player.balance;
        uint256 contractBalanceAfter = address(game).balance;

        console.log("Player balance AFTER:", playerBalanceAfter);
        console.log("Contract balance AFTER:", contractBalanceAfter);

        if (playerBalanceAfter >= playerBalanceBefore) {
            console.log("Player profit:", playerBalanceAfter - playerBalanceBefore);
        } else {
            console.log("Player loss:", playerBalanceBefore - playerBalanceAfter);
        }
        if (contractBalanceAfter >= contractBalanceBefore) {
            console.log("House profit:", contractBalanceAfter - contractBalanceBefore);
        } else {
            console.log("House loss:", contractBalanceBefore - contractBalanceAfter);
        }
        console.log("----------- END TEST -----------");

        assertTrue(settled);
        assertEq(bettor, player);
    }

    function testRefundIfVRFFails() public {
        console.log("----------- START REFUND TEST -----------");

        uint256 playerBalanceBefore = player.balance;
        uint256 contractBalanceBefore = address(game).balance;

        console.log("Player balance BEFORE:", playerBalanceBefore);
        console.log("Contract balance BEFORE:", contractBalanceBefore);

        // Player places bet
        vm.prank(player);
        uint256 requestId = game.placeBet{value: 1 ether}(0);

        console.log("Request ID:", requestId);

        uint256 contractBalanceAfterBet = address(game).balance;
        console.log("Contract balance AFTER BET:", contractBalanceAfterBet);

        // Simulate VRF failure (no fulfill call)

        console.log("Simulating VRF failure...");
        console.log("Advancing time by 31 minutes...");

        vm.warp(block.timestamp + 31 minutes);

        (,,, bool beforeSettled) = game.bets(requestId);
        console.log("Before Settled:", beforeSettled);

        // Claim refund
        vm.prank(player);
        game.claimRefund(requestId);

        console.log("Refund claimed successfully.");

        (address bettor, uint256 amount,, bool settled) = game.bets(requestId);

        console.log("Bet amount:", amount);
        console.log("Settled:", settled);

        uint256 playerBalanceAfter = player.balance;
        uint256 contractBalanceAfter = address(game).balance;

        console.log("Player balance AFTER:", playerBalanceAfter);
        console.log("Contract balance AFTER:", contractBalanceAfter);

        if (playerBalanceAfter >= playerBalanceBefore) {
            console.log("Player recovered:", playerBalanceAfter - playerBalanceBefore);
        } else {
            console.log("Unexpected player loss:", playerBalanceBefore - playerBalanceAfter);
        }

        if (contractBalanceAfter <= contractBalanceBefore) {
            console.log("House lost:", contractBalanceBefore - contractBalanceAfter);
        }

        console.log("----------- END REFUND TEST -----------");

        assertTrue(settled);
        assertEq(bettor, player);
    }

    // TOKEN BET TESTS
    function testTokenBetFlow() public {
        game.setBetToken(address(mockToken));

        mockToken.mint(player, 10 ether);

        vm.startPrank(player);
        mockToken.approve(address(game), 1 ether);

        uint256 requestId = game.placeBet(0);
        vm.stopPrank();

        mockVRF.fulfill(requestId);

        (,,, bool settled) = game.bets(requestId);
        assertTrue(settled);
    }

    // ADMIN TESTS
    function testSetFee() public {
        game.setFee(500);
        assertEq(game.feeBP(), 500);
    }

    function testSetBetAmounts() public {
        uint256[] memory newAmounts = new uint256[](2);
        newAmounts[0] = 2 ether;
        newAmounts[1] = 5 ether;

        game.setBetAmounts(newAmounts);
        assertEq(game.betAmounts(0), 2 ether);
    }

    function testSetMultipliersWeights() public {
        uint256[] memory multipliers = new uint256[](2);
        uint256[] memory weights = new uint256[](2);

        multipliers[0] = 0;
        multipliers[1] = 20;

        weights[0] = 500;
        weights[1] = 500;

        game.setMultipliersAndWeights(multipliers, weights, 1000);
        assertEq(game.totalWeight(), 1000);
    }

    // EDGE CASE TESTS
    function testRevertInvalidIndex() public {
        vm.prank(player);
        vm.expectRevert();
        game.placeBet{value: 1 ether}(99);
    }

    function testRevertWrongNativeAmount() public {
        vm.prank(player);
        vm.expectRevert();
        game.placeBet{value: 0.5 ether}(0);
    }

    function testRevertRefundTooEarly() public {
        vm.prank(player);
        uint256 requestId = game.placeBet{value: 1 ether}(0);

        vm.prank(player);
        vm.expectRevert();
        game.claimRefund(requestId);
    }

    function testOnlyOwnerSetFee() public {
        vm.prank(player);
        vm.expectRevert();
        game.setFee(500);
    }

    // Admin withdraw
    function testAdminWithdrawNative() public {
        console.log("------ ADMIN WITHDRAW NATIVE TEST ------");

        uint256 withdrawAmount = 1 ether;
        uint256 ownerBalanceBefore = address(this).balance;
        uint256 contractBalanceBefore = address(game).balance;

        console.log("Owner balance BEFORE:", ownerBalanceBefore);
        console.log("Contract balance BEFORE:", contractBalanceBefore);

        game.rescueNative(address(this), withdrawAmount);

        uint256 ownerBalanceAfter = address(this).balance;
        uint256 contractBalanceAfter = address(game).balance;

        console.log("Owner balance AFTER:", ownerBalanceAfter);
        console.log("Contract balance AFTER:", contractBalanceAfter);

        assertEq(ownerBalanceAfter, ownerBalanceBefore + withdrawAmount);
        assertEq(contractBalanceAfter, contractBalanceBefore - withdrawAmount);
    }

    function testNonAdminWithdrawNativeShouldRevert() public {
        console.log("------ NON ADMIN WITHDRAW NATIVE REVERT TEST ------");

        vm.prank(player);

        vm.expectRevert();
        game.rescueNative(player, 1 ether);
    }

    function testAdminWithdrawERC20() public {
        console.log("------ ADMIN WITHDRAW ERC20 TEST ------");

        uint256 withdrawAmount = 1000 ether;

        // Transfer mock tokens to game contract
        mockToken.transfer(address(game), withdrawAmount);

        uint256 ownerBalanceBefore = mockToken.balanceOf(address(this));
        uint256 contractBalanceBefore = mockToken.balanceOf(address(game));

        console.log("Owner token BEFORE:", ownerBalanceBefore);
        console.log("Contract token BEFORE:", contractBalanceBefore);

        game.rescueERC20(address(mockToken), address(this), withdrawAmount);

        uint256 ownerBalanceAfter = mockToken.balanceOf(address(this));
        uint256 contractBalanceAfter = mockToken.balanceOf(address(game));

        console.log("Owner token AFTER:", ownerBalanceAfter);
        console.log("Contract token AFTER:", contractBalanceAfter);

        assertEq(ownerBalanceAfter, ownerBalanceBefore + withdrawAmount);
        assertEq(contractBalanceAfter, contractBalanceBefore - withdrawAmount);
    }

    function testNonAdminWithdrawERC20ShouldRevert() public {
        console.log("------ NON ADMIN WITHDRAW ERC20 REVERT TEST ------");

        vm.prank(player);

        vm.expectRevert();
        game.rescueERC20(address(mockToken), player, 1 ether);
    }

    receive() external payable {}
}
