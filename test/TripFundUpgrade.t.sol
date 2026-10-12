// SPDX-License-Identifier: MIT
pragma solidity ^0.8.37;

import {Test} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TripFundV1} from "../src/TripFundV1.sol";
import {TripFundV2} from "../src/TripFundV2.sol";
import {ITripFund} from "../src/interfaces/ITripFund.sol";
import {TripFundToken} from "../src/TripFundToken.sol";

contract TripFundUpgradeTest is Test {
    uint256 internal constant GOAL = 1000e18;
    uint256 internal constant DURATION = 7 days;
    uint256 internal constant INITIAL_BALANCE = 10000e18;

    TripFundToken internal token;
    address internal proxy;
    uint256 internal deadline;

    address internal proxyAdminOwner = makeAddr("proxyAdminOwner");
    address internal organizer = makeAddr("organizer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal friend = makeAddr("friend");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        token = new TripFundToken();
        deadline = block.timestamp + DURATION;
        proxy = Upgrades.deployTransparentProxy(
            "TripFundV1.sol", proxyAdminOwner, abi.encodeCall(TripFundV1.initialize, (token, organizer, GOAL, deadline))
        );

        token.mint(alice, INITIAL_BALANCE);
        token.mint(bob, INITIAL_BALANCE);
    }

    function _approve(address who, uint256 amount) internal {
        vm.prank(who);
        token.approve(proxy, amount);
    }

    function _approveAndContribute(address who, uint256 amount) internal {
        _approve(who, amount);
        vm.prank(who);
        ITripFund(proxy).contribute(amount);
    }

    function test_UpgradeToV2_KeepsStateAndAddsContributeFor() public {
        _approveAndContribute(alice, 100e18);

        address implementationV1 = Upgrades.getImplementationAddress(proxy);
        address implementationV2 = address(new TripFundV2());
        ProxyAdmin proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(proxy));

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(proxy), implementationV2, "");

        Upgrades.upgradeProxy(proxy, "TripFundV2.sol", "", proxyAdminOwner);
        TripFundV2 fund = TripFundV2(proxy);

        assertNotEq(Upgrades.getImplementationAddress(proxy), implementationV1);
        assertEq(address(fund.token()), address(token));
        assertEq(fund.organizer(), organizer);
        assertEq(fund.goal(), GOAL);
        assertEq(fund.deadline(), deadline);
        assertEq(fund.contributions(alice), 100e18);
        assertEq(fund.totalRaised(), 100e18);
        assertEq(token.balanceOf(proxy), 100e18);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        fund.initialize(token, organizer, GOAL, deadline);

        _approve(bob, 200e18);
        vm.prank(bob);
        fund.contributeFor(friend, 200e18);

        assertEq(fund.contributions(friend), 200e18);
        assertEq(fund.contributions(bob), 0);
        assertEq(token.balanceOf(bob), INITIAL_BALANCE - 200e18);

        _approveAndContribute(alice, 50e18);

        assertEq(fund.contributions(alice), 150e18);
        assertEq(fund.totalRaised(), 350e18);
        assertEq(token.balanceOf(proxy), 350e18);

        vm.warp(deadline);
        vm.prank(friend);
        fund.refund();

        assertEq(token.balanceOf(friend), 200e18);
        assertEq(fund.contributions(friend), 0);
    }
}
