// SPDX-License-Identifier: MIT
pragma solidity ^0.8.37;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITripFund} from "./interfaces/ITripFund.sol";

contract TripFund is ITripFund {
    IERC20 public immutable token;
    address public immutable organizer;
    uint256 public immutable goal;
    uint256 public immutable deadline;

    mapping(address contributor => uint256 amount) public contributions;
    uint256 public totalRaised;
    bool public withdrawn;

    modifier afterDeadline() {
        if (!_deadlinePassed()) revert FundActive();
        _;
    }

    constructor(IERC20 token_, address organizer_, uint256 goal_, uint256 deadline_) {
        if (address(token_) == address(0) || organizer_ == address(0)) revert ZeroAddress();
        if (goal_ == 0) revert ZeroGoal();

        token = token_;
        organizer = organizer_;
        goal = goal_;
        deadline = deadline_;

        if (_deadlinePassed()) revert DeadlineNotInFuture();
    }

    function contribute(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (_deadlinePassed()) revert FundEnded();

        contributions[msg.sender] += amount;
        totalRaised += amount;
        emit Contributed(msg.sender, amount);

        SafeERC20.safeTransferFrom(token, msg.sender, address(this), amount);
    }

    function withdraw() external afterDeadline {
        if (msg.sender != organizer) revert NotOrganizer();
        if (!_goalReached()) revert GoalNotReached();
        if (withdrawn) revert AlreadyWithdrawn();

        withdrawn = true;
        uint256 amount = totalRaised;
        emit Withdrawn(organizer, amount);

        SafeERC20.safeTransfer(token, organizer, amount);
    }

    function refund() external afterDeadline {
        if (_goalReached()) revert GoalReached();

        uint256 amount = contributions[msg.sender];
        if (amount == 0) revert ZeroRefund();

        contributions[msg.sender] = 0;
        emit Refunded(msg.sender, amount);

        SafeERC20.safeTransfer(token, msg.sender, amount);
    }

    function _deadlinePassed() private view returns (bool) {
        // forge-lint: disable-next-line(block-timestamp)
        return block.timestamp >= deadline;
    }

    function _goalReached() private view returns (bool) {
        return totalRaised >= goal;
    }
}
