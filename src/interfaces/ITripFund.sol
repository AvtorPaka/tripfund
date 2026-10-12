// SPDX-License-Identifier: MIT
pragma solidity ^0.8.37;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITripFund {
    event Contributed(address indexed contributor, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);
    event Withdrawn(address indexed organizer, uint256 amount);

    error FundEnded();
    error FundActive();
    error NotOrganizer();
    error GoalNotReached();
    error GoalReached();
    error AlreadyWithdrawn();
    error DeadlineNotInFuture();
    error ZeroRefund();
    error ZeroAddress();
    error ZeroGoal();
    error ZeroAmount();

    function token() external view returns (IERC20);
    function organizer() external view returns (address);
    function goal() external view returns (uint256);
    function deadline() external view returns (uint256);
    function contributions(address contributor) external view returns (uint256);
    function totalRaised() external view returns (uint256);
    function withdrawn() external view returns (bool);

    function contribute(uint256 amount) external;
    function withdraw() external;
    function refund() external;
}
