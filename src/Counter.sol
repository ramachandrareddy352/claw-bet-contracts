// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
Single-Asset Claw Betting Game
- One active betting token (address(0) = native)
- Admin configurable parameters
- Chainlink VRF randomness
- Refund mechanism if VRF fails
*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract ClawBetGame is Ownable, VRFConsumerBaseV2 {

    using SafeERC20 for IERC20;

    // STRUCTS
    struct Bet {
        address player;
        uint256 amount;
        uint256 timestamp;
        bool settled;
    }

    // STATES
    address public betToken; // address(0) = native
    uint256 public feeBP;
    uint256 public constant BP_DIVISOR = 10000;

    uint256[] public betAmounts;
    uint256[] public multipliers; // 20 = 2.0x
    uint256[] public weights;
    uint256 public totalWeight;

    uint256 public constant REFUND_DELAY = 30 minutes;

    mapping(uint256 => Bet) public bets;

    // VRF
    VRFCoordinatorV2Interface public coordinator;
    uint64 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 300000;
    uint16 public requestConfirmations = 3;

    // EVENTS
    event BetPlaced(
        uint256 indexed requestId,
        address indexed player,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    event BetResolved(
        uint256 indexed requestId,
        address indexed player,
        uint256 multiplier,
        uint256 payout,
        uint256 timestamp
    );

    event BetRefunded(
        uint256 indexed requestId,
        address indexed player,
        uint256 amount
    );

    event ParametersUpdated();
    event BettingTokenUpdated(address token);
    event FeeUpdated(uint256 feeBP);

    // CONSTRUCTOR
    constructor(
        address _vrfCoordinator,
        uint64 _subId,
        bytes32 _keyHash,
        address _betToken,
        uint256 _feeBP
    ) VRFConsumerBaseV2(_vrfCoordinator) {

        coordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subId;
        keyHash = _keyHash;

        require(_feeBP <= 10000, "Fee too high");
        feeBP = _feeBP;
        betToken = _betToken;
    }

    // ADMIN CONFIGURATION
    function setBetToken(address _token) external onlyOwner {
        betToken = _token;
        emit BettingTokenUpdated(_token);
    }

    function setFee(uint256 _feeBP) external onlyOwner {
        require(_feeBP <= 10000, "Fee too high");
        feeBP = _feeBP;
        emit FeeUpdated(_feeBP);
    }

    function setBetAmounts(uint256[] calldata _amounts)
        external
        onlyOwner
    {
        require(_amounts.length > 0, "Empty");
        betAmounts = _amounts;
        emit ParametersUpdated();
    }

    function setMultipliersAndWeights(
        uint256[] calldata _multipliers,
        uint256[] calldata _weights,
        uint256 _totalWeight
    ) external onlyOwner {

        require(_multipliers.length == _weights.length, "Length mismatch");
        require(_multipliers.length > 0, "Empty");

        uint256 sum;
        for (uint256 i; i < _weights.length; ) {
            sum += _weights[i];
            unchecked { ++i; }
        }

        require(sum == _totalWeight, "Invalid weight sum");

        multipliers = _multipliers;
        weights = _weights;
        totalWeight = _totalWeight;

        emit ParametersUpdated();
    }

    // USER BET
    function placeBet(uint256 index)
        external
        payable
        returns (uint256 requestId)
    {
        require(index < betAmounts.length, "Invalid index");

        uint256 amount = betAmounts[index];

        if (betToken == address(0)) {
            require(msg.value == amount, "Incorrect native amount");
        } else {
            require(msg.value == 0, "No native allowed");
            IERC20(betToken).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
        }

        requestId = coordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1
        );

        bets[requestId] = Bet({
            player: msg.sender,
            amount: amount,
            timestamp: block.timestamp,
            settled: false
        });

        emit BetPlaced(
            requestId,
            msg.sender,
            betToken,
            amount,
            block.timestamp
        );
    }

    // VRF CALLBACK
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {

        Bet storage betData = bets[requestId];
        if (betData.settled || betData.player == address(0)) return;

        uint256 rnd = randomWords[0] % totalWeight;

        uint256 acc;
        uint256 multiplier;

        for (uint256 i; i < weights.length; ) {
            acc += weights[i];
            if (rnd < acc) {
                multiplier = multipliers[i];
                break;
            }
            unchecked { ++i; }
        }

        uint256 fee = (betData.amount * feeBP) / BP_DIVISOR;
        uint256 net = betData.amount - fee;
        uint256 payout = (net * multiplier) / 10;

        betData.settled = true;

        if (payout > 0) {
            _transferOut(betData.player, payout);
        }

        emit BetResolved(
            requestId,
            betData.player,
            multiplier,
            payout,
            block.timestamp
        );
    }

    // REFUND IF VRF FAILS
    function claimRefund(uint256 requestId)
        external
    {
        Bet storage betData = bets[requestId];

        require(!betData.settled, "Already settled");
        require(betData.player == msg.sender, "Not player");
        require(
            block.timestamp > betData.timestamp + REFUND_DELAY,
            "Too early"
        );

        betData.settled = true;

        _transferOut(msg.sender, betData.amount);

        emit BetRefunded(requestId, msg.sender, betData.amount);
    }

    // INTERNAL TRANSFER
    function _transferOut(address to, uint256 amount) internal {
        if (betToken == address(0)) {
            require(address(this).balance >= amount, "Insufficient native");

            (bool success, ) = payable(to).call{value: amount}("");
            require(success, "Native transfer failed");
        } else {
            IERC20 token = IERC20(betToken);
            require(token.balanceOf(address(this)) >= amount, "Insufficient token");
            token.safeTransfer(to, amount);
        }
    }

    // RESCUE
    function rescueERC20(address token, address receiver, uint256 amount)
        external
        onlyOwner
    {
        IERC20(token).safeTransfer(receiver, amount);
    }

    function rescueNative(address receiver, uint256 amount)
        external
        onlyOwner
    {
        (bool success, ) = payable(receiver).call{value: amount}("");
        require(success, "Native transfer failed");
    }

    receive() external payable {}
}