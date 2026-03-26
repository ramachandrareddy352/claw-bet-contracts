// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeERC20, IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {VRFV2PlusWrapperConsumerBase} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IVRFV2PlusWrapper} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";

contract ClawBetGame is VRFV2PlusWrapperConsumerBase, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // STRUCTS
    struct Bet {
        address player;
        bool isSettled;
        uint64 startTime;
        uint256 amount; // bet amount
        uint256 payout; // after fullfill the payer received amount
        uint256 maxPayoutReserved; // max multiplier(at bet time) * bet amount
        uint256 vrfFee; // amount paid in native bnb to call vrf
    }

    uint256 public constant BP_DIVISOR = 10000;
    uint64 public constant REFUND_DELAY = 30 minutes;

    IERC20 public immutable i_betToken; // only usdt

    // VRF
    address public immutable i_wrapperAddress;
    uint32 public callbackGasLimit = 300000;
    uint256 public vrfInitialFee = 400000000000000; // 0.0004

    // STATES
    address public clawOwner;
    uint256 public feeBP = 200; // 2%

    uint256 public availableLiquidity; // withdrawable house funds (token)
    uint256 public pendingLiquidity; // sum of max possible payouts for all unsettled bets
    uint256 public pendingRawLiquidity; // sum of raw bet amounts that are still pending

    uint256[] public betAmounts;
    uint256[] public multipliers; // 20 = 2.0x, always last one should be at maximum, or else maxPayout check fails
    uint256[] public weights;
    uint256 public totalWeight;

    mapping(uint256 => Bet) public bets;

    // EVENTS
    event ClawOwnershipTransferred(address indexed previousClawOwner, address indexed newClawOwner);
    event BetPlaced(
        uint256 indexed requestId, address indexed player, uint256 amount, uint256 reqPrice, uint64 startTime
    );
    event BetResolved(
        uint256 indexed requestId, address indexed player, uint256 multiplier, uint256 payout, uint64 resolvedTime
    );
    event ForceRefund(uint256 indexed requestId, address indexed player, uint256 amount);
    event VRFUpdated(uint32 callbackGasLimit, uint256 vrfInitialFee);
    event ParametersUpdated();
    event FeeUpdated(uint256 feeBP);
    event FeesWithdrawn(address indexed token, address indexed to, uint256 amount);

    modifier onlyClawOwner() {
        require(msg.sender == clawOwner, "Caller is not claw owner");
        _;
    }

    constructor(address _wrapperAddress, address _clawOwner, address _betToken)
        VRFV2PlusWrapperConsumerBase(_wrapperAddress)
    {
        i_wrapperAddress = _wrapperAddress;
        i_betToken = IERC20(_betToken);

        clawOwner = _clawOwner;

        // Default bet amounts (only USDT on bnb 18 decimals token)
        betAmounts = [1 ether, 10 ether, 20 ether, 50 ether, 100 ether];
        multipliers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];
        weights = [70, 65, 60, 58, 56, 54, 52, 50, 48, 37, 70, 65, 60, 55, 50, 55, 30, 25, 20, 15, 5];
        totalWeight = 1000;

        // Validate initials
        uint256 len = weights.length;
        require(multipliers.length == len, "Length mismatch");

        uint256 sum = 0;
        for (uint256 i = 0; i < len;) {
            sum += weights[i];
            unchecked {
                ++i;
            }
        }
        require(sum == totalWeight, "Weights sum mismatch");
    }

    function _requestVRF() internal returns (uint256 requestId, uint256 reqPrice) {
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}));
        (requestId, reqPrice) = requestRandomnessPayInNative(
            callbackGasLimit,
            3,
            1, // 1 random word (same as original Claw)
            extraArgs
        );
    }

    function syncExcessLiquidity() public {
        uint256 balance = i_betToken.balanceOf(address(this));
        uint256 expected = pendingRawLiquidity + availableLiquidity;

        if (balance > expected) {
            uint256 excess = balance - expected;
            availableLiquidity += excess;
        }
    }

    // USER BET
    function placeBet(uint256 _index)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 requestId, uint256 reqPrice)
    {
        require(_index < betAmounts.length, "Invalid index");

        // Must send atleast VRF prepay (native only)
        require(msg.value == vrfInitialFee, "Insufficient native payment for fees");

        uint256 amount = betAmounts[_index];

        uint256 netAmount = amount * (BP_DIVISOR - feeBP) / BP_DIVISOR;
        uint256 maxPossiblePayout = (netAmount * multipliers[multipliers.length - 1]) / 10;

        syncExcessLiquidity();

        // SOLVENCY CHECK
        require(availableLiquidity >= pendingLiquidity + maxPossiblePayout, "Insufficient liquidity");

        // TRANSFER BET TOKEN (ERC20 ONLY)
        i_betToken.safeTransferFrom(msg.sender, address(this), amount);

        pendingLiquidity += maxPossiblePayout;
        pendingRawLiquidity += amount;

        (requestId, reqPrice) = _requestVRF();

        // excess fee is taken by the protocol as operation fees
        require(reqPrice <= vrfInitialFee, "VRF fee exceeded");

        bets[requestId] = Bet({
            player: msg.sender,
            amount: amount,
            startTime: uint64(block.timestamp),
            isSettled: false,
            payout: 0,
            vrfFee: reqPrice,
            maxPayoutReserved: maxPossiblePayout
        });

        emit BetPlaced(requestId, msg.sender, amount, reqPrice, uint64(block.timestamp));
    }

    // VRF CALLBACK
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        Bet storage betData = bets[_requestId];
        if (betData.isSettled || betData.player == address(0)) return;

        uint256 rnd = _randomWords[0] % totalWeight;

        uint256 acc;
        uint256 multiplier;
        uint256 len = weights.length;

        for (uint256 i; i < len;) {
            acc += weights[i];
            if (rnd < acc) {
                multiplier = multipliers[i];
                break;
            }
            unchecked {
                ++i;
            }
        }

        uint256 betAmount = betData.amount;

        uint256 fee = (betAmount * feeBP) / BP_DIVISOR;
        uint256 netAmount = betAmount - fee;
        uint256 actualPayout = (netAmount * multiplier) / 10;

        betData.isSettled = true;
        betData.payout = actualPayout; // do not delete the data, we use it in frontend

        pendingLiquidity -= betData.maxPayoutReserved;
        pendingRawLiquidity -= betAmount;

        availableLiquidity += fee; // fees is always added into available liquidity

        if (actualPayout <= netAmount) {
            // PROTOCOL WIN
            availableLiquidity += (netAmount - actualPayout);
        } else {
            // PLAYER WIN
            availableLiquidity -= (actualPayout - netAmount);
        }

        if (actualPayout > 0) {
            i_betToken.safeTransfer(betData.player, actualPayout);
        }

        emit BetResolved(_requestId, betData.player, multiplier, actualPayout, uint64(block.timestamp));
    }

    // REFUND IF VRF FAILS
    function ForceSettle(uint256 _requestId) external nonReentrant {
        Bet storage betData = bets[_requestId];

        require(!betData.isSettled, "Already settled");
        require(uint64(block.timestamp) > betData.startTime + REFUND_DELAY, "Too early");

        betData.isSettled = true;

        pendingLiquidity -= betData.maxPayoutReserved;
        pendingRawLiquidity -= betData.amount;

        i_betToken.safeTransfer(betData.player, betData.amount);

        emit ForceRefund(_requestId, betData.player, betData.amount);
    }

    // WITHDRAW ASSETS
    function withdrawFunds(address _token, address _to, uint256 _amount) external onlyClawOwner {
        require(_to != address(0), "Invalid address");
        require(_amount > 0, "Invalid amount");

        bool wasPaused = paused();
        if (!wasPaused) {
            _pause();
        }
        syncExcessLiquidity();

        if (_token == address(0)) {
            //  NATIVE (BNB)
            require(address(this).balance >= _amount, "Insufficient BNB");
            (bool success,) = payable(_to).call{value: _amount}("");
            require(success, "BNB transfer failed");
        } else if (_token == address(i_betToken)) {
            // GAME TOKEN (STRICT)
            require(_amount <= availableLiquidity, "Exceeds available liquidity");
            require(availableLiquidity - _amount >= pendingLiquidity, "Would break pending payouts");

            availableLiquidity -= _amount;

            IERC20(_token).safeTransfer(_to, _amount);
        } else {
            // RECOVER WRONG TOKENS
            uint256 balance = IERC20(_token).balanceOf(address(this));
            require(_amount <= balance, "Insufficient token balance");

            IERC20(_token).safeTransfer(_to, _amount);
        }

        if (!wasPaused) {
            _unpause();
        }

        emit FeesWithdrawn(_token, _to, _amount);
    }

    // ADMIN CONFIGURATION
    function transferClawOwnership(address _newClawOwner) external onlyClawOwner {
        require(_newClawOwner != address(0), "New claw owner cannot be zero");
        emit ClawOwnershipTransferred(clawOwner, _newClawOwner);

        clawOwner = _newClawOwner;
    }

    function updateVRF(uint32 _callbackGasLimit, uint256 _vrfInitialFee) external onlyClawOwner {
        require(_callbackGasLimit > 200000, "Too low VRF callback gas limit");
        require(_vrfInitialFee > 10000000000000, "Too low VRF initial fees"); // atleast 0.00001

        callbackGasLimit = _callbackGasLimit;
        vrfInitialFee = _vrfInitialFee;

        emit VRFUpdated(_callbackGasLimit, _vrfInitialFee);
    }

    function setFee(uint256 _feeBP) external onlyClawOwner {
        require(_feeBP <= 1000, "Fee too high"); // 10% maximum
        feeBP = _feeBP;
        emit FeeUpdated(_feeBP);
    }

    function setBetAmounts(uint256[] calldata _amounts) external onlyClawOwner {
        uint256 len = _amounts.length;
        require(len > 0, "Invalid amounts length"); // DOS protection
        for (uint256 i = 0; i < len;) {
            require(_amounts[i] > 0, "Zero bet amount");
            unchecked {
                ++i;
            }
        }

        betAmounts = _amounts;
        emit ParametersUpdated();
    }

    function setMultipliersAndWeights(
        uint256[] calldata _multipliers,
        uint256[] calldata _weights,
        uint256 _totalWeight
    ) external onlyClawOwner {
        uint256 len = _weights.length;
        require(_multipliers.length == len, "Length mismatch");
        require(_multipliers.length > 0, "Empty");

        uint256 sum;
        for (uint256 i; i < len;) {
            sum += _weights[i];
            unchecked {
                ++i;
            }
        }

        require(sum == _totalWeight, "Invalid weight sum");

        multipliers = _multipliers;
        weights = _weights;
        totalWeight = _totalWeight;

        emit ParametersUpdated();
    }

    function pause() external onlyClawOwner {
        _pause();
    }

    function unpause() external onlyClawOwner {
        _unpause();
    }

    receive() external payable {}
}
