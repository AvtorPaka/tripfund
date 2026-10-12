// SPDX-License-Identifier: MIT
pragma solidity ^0.8.37;

import {ITripFund} from "./ITripFund.sol";

interface ITripFundV2 is ITripFund {
    event ContributedFor(address indexed payer, address indexed beneficiary, uint256 amount);

    function contributeFor(address beneficiary, uint256 amount) external;
}
