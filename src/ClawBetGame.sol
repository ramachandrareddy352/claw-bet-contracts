// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
Single-Asset Claw Betting Game
- One active betting token (address(0) = native)
- Admin configurable parameters
- Uses Chainlink VRF v2.5 DIRECT FUNDING
- Refund mechanism if VRF fails
*/

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20, IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {VRFV2PlusWrapperConsumerBase} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IVRFV2PlusWrapper} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";

contract ClawBetGame is VRFV2PlusWrapperConsumerBase, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // STRUCTS
    struct Bet {
        address player;
        bool settled;
        uint64 timestamp;
        uint256 amount;
        uint256 payout;
        uint256 paid; // amount paid in link to call vrf
    }

    address public clawOwner;

    uint64 public constant REFUND_DELAY = 30 minutes;
    uint256 public constant BP_DIVISOR = 10000;

    // STATES
    address public betToken; // address(0) = native
    uint256 public feeBP = 200; // 2%

    uint256[] public betAmounts;
    uint256[] public multipliers; // 20 = 2.0x, always last one should be at maximum, or else maxPayout check fails
    uint256[] public weights;
    uint256 public totalWeight;

    mapping(uint256 => Bet) public bets;

    // VRF
    address public immutable i_wrapperAddress;
    address public immutable i_linkAddress;
    uint32 public callbackGasLimit = 300000;
    uint16 public requestConfirmations = 3;
    bool public enableNativePayment = true; // true => uses native token in VRF, false => uses LINK token in VRF

    // EVENTS
    event ClawOwnershipTransferred(address indexed previousClawOwner, address indexed newClawOwner);
    event BetPlaced(
        uint256 indexed requestId,
        address indexed player,
        address indexed token,
        uint256 amount,
        uint256 reqPrice,
        uint64 timestamp
    );
    event BetResolved(
        uint256 indexed requestId, address indexed player, uint256 multiplier, uint256 payout, uint64 timestamp
    );
    event BetRefunded(uint256 indexed requestId, address indexed player, uint256 amount);
    event VRFUpdated(uint32 callbackGasLimit, uint16 requestConfirmations, bool nativePayment);
    event ParametersUpdated();
    event BettingTokenUpdated(address token);
    event FeeUpdated(uint256 feeBP);

    modifier onlyClawOwner() {
        require(msg.sender == clawOwner, "Caller is not claw owner");
        _;
    }

    constructor(address _wrapperAddress, address _linkAddress, address _clawOwner, address _betToken)
        VRFV2PlusWrapperConsumerBase(_wrapperAddress)
    {
        i_wrapperAddress = _wrapperAddress;
        i_linkAddress = _linkAddress;
        betToken = _betToken;

        clawOwner = _clawOwner;
        emit ClawOwnershipTransferred(address(0), _clawOwner);

        // Default bet amounts (assumes 18 decimals token)
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

    // USER BET
    function placeBet(uint256 _index) external payable nonReentrant returns (uint256 requestId) {
        require(_index < betAmounts.length, "Invalid index");

        uint256 amount = betAmounts[_index];
        uint256 netAmount = amount * (BP_DIVISOR - feeBP) / BP_DIVISOR;
        uint256 maxPossiblePayout = (netAmount * multipliers[multipliers.length - 1]) / 10;

        uint256 vrfFee;
        if (enableNativePayment) {
            vrfFee = IVRFV2PlusWrapper(i_wrapperAddress).calculateRequestPriceNative(callbackGasLimit, 1);
        } else {
            vrfFee = IVRFV2PlusWrapper(i_wrapperAddress).calculateRequestPrice(callbackGasLimit, 1);
        }

        if (betToken == address(0)) {
            require(msg.value == amount, "Incorrect native amount");
            require(
                address(this).balance - msg.value > maxPossiblePayout + (enableNativePayment ? vrfFee : 0), "Insufficient liquidity"
            );
        } else {
            require(msg.value == 0, "No native allowed");
            IERC20(betToken).safeTransferFrom(msg.sender, address(this), amount);

            require(IERC20(betToken).balanceOf(address(this)) > maxPossiblePayout, "Insufficient liquidity");
        }

        if (!enableNativePayment) {
            require(IERC20(i_linkAddress).balanceOf(address(this)) > vrfFee, "Insufficient LINK for VRF");
        }

        uint256 reqPrice;
        bytes memory extraArgs =
            VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment}));

        if (enableNativePayment) {
            (requestId, reqPrice) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs);
        } else {
            (requestId, reqPrice) = requestRandomness(callbackGasLimit, requestConfirmations, 1, extraArgs);
        }

        bets[requestId] = Bet({
            player: msg.sender,
            amount: amount,
            timestamp: uint64(block.timestamp),
            settled: false,
            payout: 0,
            paid: reqPrice
        });

        emit BetPlaced(requestId, msg.sender, betToken, amount, reqPrice, uint64(block.timestamp));
    }

    // VRF CALLBACK
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        Bet storage betData = bets[_requestId];
        if (betData.settled || betData.player == address(0)) return;

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

        uint256 fee = (betData.amount * feeBP) / BP_DIVISOR;
        uint256 net = betData.amount - fee;
        uint256 payout = (net * multiplier) / 10;

        betData.settled = true;
        betData.payout = payout; // do not delete the data, we use it in frontend

        if (payout > 0) {
            _transferOut(betData.player, payout);
        }

        emit BetResolved(_requestId, betData.player, multiplier, payout, uint64(block.timestamp));
    }

    // REFUND IF VRF FAILS
    function claimRefund(uint256 _requestId) external nonReentrant {
        Bet storage betData = bets[_requestId];

        require(!betData.settled, "Already settled");
        require(betData.player == msg.sender, "Not player");
        require(uint64(block.timestamp) > betData.timestamp + REFUND_DELAY, "Too early");

        betData.settled = true;

        _transferOut(msg.sender, betData.amount);

        emit BetRefunded(_requestId, msg.sender, betData.amount);
    }

    // INTERNAL TRANSFER
    function _transferOut(address _to, uint256 _amount) internal {
        if (betToken == address(0)) {
            require(address(this).balance >= _amount, "Insufficient native");

            (bool success,) = payable(_to).call{value: _amount}("");
            require(success, "Native transfer failed");
        } else {
            IERC20 token = IERC20(betToken);
            require(token.balanceOf(address(this)) >= _amount, "Insufficient token");

            token.safeTransfer(_to, _amount);
        }
    }

    // WITHDRAW ASSETS
    function withdrawERC20(address _token, address _receiver, uint256 _amount) external onlyClawOwner {
        IERC20(_token).safeTransfer(_receiver, _amount);
    }

    function withdrawNative(address _receiver, uint256 _amount) external onlyClawOwner {
        (bool success,) = payable(_receiver).call{value: _amount}("");
        require(success, "Native transfer failed");
    }

    // ADMIN CONFIGURATION
    function transferClawOwnership(address _newClawOwner) external onlyClawOwner {
        require(_newClawOwner != address(0), "New claw owner cannot be zero");
        emit ClawOwnershipTransferred(clawOwner, _newClawOwner);

        clawOwner = _newClawOwner;
    }

    function updateVRF(uint32 _callbackGasLimit, uint16 _requestConfirmations, bool _enableNativePayment)
        external
        onlyClawOwner
    {
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
        enableNativePayment = _enableNativePayment;
        emit VRFUpdated(_callbackGasLimit, _requestConfirmations, _enableNativePayment);
    }

    function setBetToken(address _token) external onlyClawOwner {
        betToken = _token;
        emit BettingTokenUpdated(_token);
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

    receive() external payable {}
}
