// SPDX-License-Identifier: MIT
pragma solidity ^0.8.37;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TripFundV1} from "./TripFundV1.sol";
import {ITripFundV2} from "./interfaces/ITripFundV2.sol";

/// @custom:oz-upgrades-from TripFundV1
contract TripFundV2 is TripFundV1, ITripFundV2 {
    function contributeFor(address beneficiary, uint256 amount) external {
        if (beneficiary == address(0)) revert ZeroAddress();

        _recordContribution(beneficiary, amount);
        emit ContributedFor(msg.sender, beneficiary, amount);

        SafeERC20.safeTransferFrom(token, msg.sender, address(this), amount);
    }
}
