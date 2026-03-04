// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(address receiver) ERC20("Test Token", "TEST") {
        _mint(receiver, 1_000_000 * 1e18);
    }
}
