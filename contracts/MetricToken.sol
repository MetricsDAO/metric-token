// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MetricToken is ERC20 { 
    uint256 public maxSupply = 1000000000000000000000000000; // 1 billion tokens

    constructor() ERC20("Metric Token", "METRIC") {
        _mint(msg.sender, maxSupply);
    }
}