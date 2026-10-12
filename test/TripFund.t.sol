// SPDX-License-Identifier: MIT
pragma solidity ^0.8.37;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {TripFund} from "../src/TripFund.sol";
import {TripFundToken} from "../src/TripFundToken.sol";

abstract contract TripFundTestBase is Test {
    uint256 internal constant GOAL = 1000e18;
    uint256 internal constant DURATION = 7 days;
    uint256 internal constant INITIAL_BALANCE = 10000e18;

    TripFundToken internal token;
    TripFund internal fund;
    uint256 internal deadline;

    address internal organizer = makeAddr("organizer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal stranger = makeAddr("stranger");

    struct Ledger {
        uint256 contribution;
        uint256 totalRaised;
        uint256 userBalance;
        uint256 fundBalance;
    }

    function setUp() public virtual {
        token = new TripFundToken();
        deadline = block.timestamp + DURATION;
        fund = new TripFund(token, organizer, GOAL, deadline);

        token.mint(alice, INITIAL_BALANCE);
        token.mint(bob, INITIAL_BALANCE);
    }

    function _approve(address who, uint256 amount) internal {
        vm.prank(who);
        token.approve(address(fund), amount);
    }

    function _contribute(address who, uint256 amount) internal {
        vm.prank(who);
        fund.contribute(amount);
    }

    function _approveAndContribute(address who, uint256 amount) internal {
        _approve(who, amount);
        _contribute(who, amount);
    }

    function _reachGoalExactly() internal {
        _approveAndContribute(alice, GOAL / 8);
        _approveAndContribute(bob, GOAL - GOAL / 8);
    }

    function _withdraw(address who) internal {
        vm.prank(who);
        fund.withdraw();
    }

    function _refund(address who) internal {
        vm.prank(who);
        fund.refund();
    }

    function _ledger(address who) internal view returns (Ledger memory) {
        return Ledger({
            contribution: fund.contributions(who),
            totalRaised: fund.totalRaised(),
            userBalance: token.balanceOf(who),
            fundBalance: token.balanceOf(address(fund))
        });
    }

    function _assertLedgerUnchanged(address who, Ledger memory before) internal view {
        Ledger memory current = _ledger(who);
        assertEq(current.contribution, before.contribution, "contribution changed");
        assertEq(current.totalRaised, before.totalRaised, "totalRaised changed");
        assertEq(current.userBalance, before.userBalance, "user balance changed");
        assertEq(current.fundBalance, before.fundBalance, "fund balance changed");
    }
}

contract TripFundContributeTest is TripFundTestBase {
    function test_Contribute_TwoContributorsWithRepeatedContributions() public {
        _approveAndContribute(alice, 100e18);
        _approveAndContribute(bob, 300e18);
        _approveAndContribute(alice, 50e18);

        assertEq(fund.contributions(alice), 150e18);
        assertEq(fund.contributions(bob), 300e18);
        assertEq(fund.totalRaised(), 450e18);
        assertEq(token.balanceOf(address(fund)), 450e18);
        assertEq(token.balanceOf(alice), INITIAL_BALANCE - 150e18);
        assertEq(token.balanceOf(bob), INITIAL_BALANCE - 300e18);
    }

    function test_RevertWhen_ContributeZeroAmount() public {
        _approveAndContribute(alice, 100e18);
        Ledger memory before = _ledger(alice);

        vm.expectRevert(TripFund.ZeroAmount.selector);
        _contribute(alice, 0);

        _assertLedgerUnchanged(alice, before);
    }

    function test_RevertWhen_ContributeWithInsufficientBalance() public {
        _approveAndContribute(alice, 100e18);
        uint256 balance = token.balanceOf(alice);
        uint256 amount = balance + 1;
        _approve(alice, amount);
        Ledger memory before = _ledger(alice);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, balance, amount));
        _contribute(alice, amount);

        _assertLedgerUnchanged(alice, before);
    }

    function test_RevertWhen_ContributeWithInsufficientAllowance() public {
        _approveAndContribute(alice, 100e18);
        _approve(alice, 50e18);
        Ledger memory before = _ledger(alice);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(fund), 50e18, 51e18)
        );
        _contribute(alice, 51e18);

        _assertLedgerUnchanged(alice, before);
    }

    function test_Contribute_OneSecondBeforeDeadline() public {
        vm.warp(deadline - 1);
        _approveAndContribute(alice, 100e18);

        assertEq(fund.contributions(alice), 100e18);
        assertEq(fund.totalRaised(), 100e18);
    }

    function test_RevertWhen_ContributeExactlyAtDeadline() public {
        vm.warp(deadline);
        _approve(alice, 100e18);
        Ledger memory before = _ledger(alice);

        vm.expectRevert(TripFund.FundEnded.selector);
        _contribute(alice, 100e18);

        _assertLedgerUnchanged(alice, before);
    }
}

contract TripFundPayoutTest is TripFundTestBase {
    function test_RevertWhen_PayoutBeforeDeadlineEvenIfGoalReached() public {
        _reachGoalExactly();
        uint256 aliceContribution = fund.contributions(alice);
        vm.warp(deadline - 1);

        vm.expectRevert(TripFund.FundActive.selector);
        _withdraw(organizer);

        vm.expectRevert(TripFund.FundActive.selector);
        _refund(alice);

        assertFalse(fund.withdrawn());
        assertEq(fund.contributions(alice), aliceContribution);
        assertEq(token.balanceOf(address(fund)), GOAL);
    }

    function test_Withdraw_WhenGoalReachedExactly() public {
        _reachGoalExactly();
        vm.warp(deadline);

        _withdraw(organizer);

        assertTrue(fund.withdrawn());
        assertEq(token.balanceOf(organizer), GOAL);
        assertEq(token.balanceOf(address(fund)), 0);
        assertEq(fund.totalRaised(), GOAL);
    }

    function test_Withdraw_WhenGoalExceeded() public {
        _approveAndContribute(alice, GOAL);
        _approveAndContribute(bob, 250e18);
        vm.warp(deadline + 1 days);

        _withdraw(organizer);

        assertEq(token.balanceOf(organizer), GOAL + 250e18);
        assertEq(token.balanceOf(address(fund)), 0);
        assertEq(fund.totalRaised(), GOAL + 250e18);
    }

    function test_RevertWhen_WithdrawByNonOrganizer() public {
        _reachGoalExactly();
        vm.warp(deadline);

        vm.expectRevert(TripFund.NotOrganizer.selector);
        _withdraw(stranger);

        assertFalse(fund.withdrawn());
        assertEq(token.balanceOf(address(fund)), GOAL);
        assertEq(token.balanceOf(stranger), 0);
    }

    function test_RevertWhen_WithdrawTwice() public {
        _reachGoalExactly();
        vm.warp(deadline);
        _withdraw(organizer);

        vm.expectRevert(TripFund.AlreadyWithdrawn.selector);
        _withdraw(organizer);

        assertEq(token.balanceOf(organizer), GOAL);
    }

    function test_RevertWhen_WithdrawWhenGoalNotReached() public {
        _approveAndContribute(alice, GOAL - 1);
        vm.warp(deadline);

        vm.expectRevert(TripFund.GoalNotReached.selector);
        _withdraw(organizer);

        assertFalse(fund.withdrawn());
        assertEq(token.balanceOf(organizer), 0);
        assertEq(token.balanceOf(address(fund)), GOAL - 1);
    }

    function test_RevertWhen_RefundWhenGoalReached() public {
        _reachGoalExactly();
        vm.warp(deadline);
        Ledger memory before = _ledger(alice);

        vm.expectRevert(TripFund.GoalReached.selector);
        _refund(alice);

        _assertLedgerUnchanged(alice, before);
    }

    function test_Refund_IndependentRefundsWhenGoalNotReached() public {
        _approveAndContribute(alice, 300e18);
        _approveAndContribute(bob, 200e18);
        _approveAndContribute(alice, 100e18);
        vm.warp(deadline);

        _refund(alice);

        assertEq(token.balanceOf(alice), INITIAL_BALANCE);
        assertEq(fund.contributions(alice), 0);
        assertEq(fund.contributions(bob), 200e18);
        assertEq(token.balanceOf(address(fund)), 200e18);

        _refund(bob);

        assertEq(token.balanceOf(bob), INITIAL_BALANCE);
        assertEq(fund.contributions(bob), 0);
        assertEq(token.balanceOf(address(fund)), 0);
        assertEq(fund.totalRaised(), 600e18);
    }

    function test_RevertWhen_RefundTwice() public {
        _approveAndContribute(alice, 100e18);
        _approveAndContribute(bob, 100e18);
        vm.warp(deadline);
        _refund(alice);

        vm.expectRevert(TripFund.ZeroRefund.selector);
        _refund(alice);

        assertEq(token.balanceOf(alice), INITIAL_BALANCE);
        assertEq(token.balanceOf(address(fund)), 100e18);
    }
}

contract TripFundDirectTransferTest is TripFundTestBase {
    uint256 internal constant DIRECT_AMOUNT = 77e18;

    function _sendDirectly(address from, uint256 amount) internal {
        vm.prank(from);
        bool success = token.transfer(address(fund), amount);
        assertTrue(success);
    }

    function test_DirectTransfer_DoesNotChangeTotalRaised() public {
        _approveAndContribute(alice, 100e18);
        _sendDirectly(bob, DIRECT_AMOUNT);

        assertEq(fund.totalRaised(), 100e18);
        assertEq(fund.contributions(bob), 0);
        assertEq(token.balanceOf(address(fund)), 100e18 + DIRECT_AMOUNT);
    }

    function test_DirectTransfer_RemainsAfterWithdraw() public {
        _reachGoalExactly();
        _sendDirectly(bob, DIRECT_AMOUNT);
        vm.warp(deadline);

        _withdraw(organizer);

        assertEq(token.balanceOf(organizer), GOAL);
        assertEq(token.balanceOf(address(fund)), DIRECT_AMOUNT);
        assertEq(fund.totalRaised(), GOAL);
    }

    function test_DirectTransfer_RemainsAfterAllRefunds() public {
        _approveAndContribute(alice, 300e18);
        _approveAndContribute(bob, 200e18);
        _sendDirectly(bob, DIRECT_AMOUNT);
        vm.warp(deadline);

        _refund(alice);
        _refund(bob);

        assertEq(token.balanceOf(alice), INITIAL_BALANCE);
        assertEq(token.balanceOf(bob), INITIAL_BALANCE - DIRECT_AMOUNT);
        assertEq(token.balanceOf(address(fund)), DIRECT_AMOUNT);
        assertEq(fund.totalRaised(), 500e18);
    }
}
