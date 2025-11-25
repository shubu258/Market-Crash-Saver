// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "lib/forge-std/src/Test.sol";
import {MarketInvest} from "../src/MarketInvest.sol";
import {StdAssertions} from "lib/forge-std/src/StdAssertions.sol";

// Minimal mock for Chainlink aggregator
contract MockV3Aggregator {
    int256 private answer;
    uint8 private decimalsValue = 18;
    uint256 private updatedAt;

    function setPrice(int256 _answer) external {
        answer = _answer;
        updatedAt = block.timestamp;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, answer, 0, updatedAt, 0);
    }

    function decimals() external view returns (uint8) {
        return decimalsValue;
    }
}

contract MarketInvestTest is Test {
    MarketInvest public market;
    MockV3Aggregator public mockFeed;
    address public owner = address(0xA11CE);
    address public user1 = address(0xB0B);
    uint256 public expiry;

    function setUp() public {
        // Deploy mock Chainlink feed
        mockFeed = new MockV3Aggregator();
        // Deploy contract with mock and owner
        market = new MarketInvest(address(mockFeed), owner);

        expiry = block.timestamp + 30 days;
        vm.deal(user1, 10 ether); // Give user some ETH
    }

    function testDeployment() public view {
        assertEq(address(market.priceFeed()), address(mockFeed));
        assertEq(market.owner(), owner);
    }

    function testMarketBuyPolicy() public {
        vm.startPrank(user1);

        vm.expectEmit(true, true, true, true);
        emit MarketInvest.marketPolicyPurchased({
            policyId: 1,
            marketType: MarketInvest.MarketType.MarketCrash,
            user: user1,
            depositAmount: 0.99 ether,
            lastDeposited: block.timestamp,
            claimActive: true,
            expiry: expiry
        });

        market.buyMarketPolicyf{value: 1 ether}(expiry, MarketInvest.MarketType.MarketCrash);

        vm.stopPrank();

        (uint256 id, address user,, uint256 deposit,, bool active,) = market.marketPolicy(1);
        assertEq(id, 1);
        assertEq(user, user1);
        assertEq(active, true);
        assertApproxEqAbs(deposit, 0.99 ether, 1);
    }

    function testNaturalDisasterBuy() public {
        vm.startPrank(user1);

        vm.expectEmit(true, true, true, true);
        emit MarketInvest.marketPolicyPurchased({
            policyId: 1,
            marketType: MarketInvest.MarketType.NaturalDisaster,
            user: user1,
            depositAmount: 0.99 ether,
            lastDeposited: block.timestamp,
            claimActive: true,
            expiry: expiry
        });

        market.buyMarketPolicyf{value: 1 ether}(expiry, MarketInvest.MarketType.NaturalDisaster);

        vm.stopPrank();
        (uint256 id, address user,, uint256 deposit,, bool active,) = market.marketPolicy(1);
        assertEq(id, 1);
        assertEq(user, user1);
        assertEq(active, true);
        assertApproxEqAbs(deposit, 0.99 ether, 1);
    }

    function testStableDisasterBuy() public {
        vm.startPrank(user1);

        market.buyMarketPolicyf{value: 1 ether}(expiry, MarketInvest.MarketType.StablePleg);

        vm.stopPrank();
        (uint256 id, address user,, uint256 deposit,, bool active,) = market.marketPolicy(1);
        assertEq(id, 1);
        assertEq(user, user1);
        assertEq(active, true);
        assertApproxEqAbs(deposit, 0.99 ether, 1);
    }

    function testClaimMarketCrash() public {
        vm.deal(address(market), 10 ether);

        vm.startPrank(user1);
        market.buyMarketPolicyf{value: 1 ether}(expiry, MarketInvest.MarketType.MarketCrash);
        vm.stopPrank();

        mockFeed.setPrice(int256(0.2 ether));

        vm.startPrank(user1);
        market.claimMarketCrash(1);
        vm.stopPrank();
    }

    function testClaimNaturalCrash() public {
        vm.deal(address(market), 10 ether);

        vm.startPrank(user1);
        market.buyMarketPolicyf{value: 1 ether}(expiry, MarketInvest.MarketType.NaturalDisaster);
        vm.stopPrank();

        vm.startPrank(user1);
        market.claimNaturalClamity(120, 1);
        vm.stopPrank();
    }

    function testStableCrash() public {
        vm.deal(address(market), 10 ether);

        vm.startPrank(user1);
        market.buyMarketPolicyf{value: 1 ether}(expiry, MarketInvest.MarketType.StablePleg);
        vm.stopPrank();

        mockFeed.setPrice(9);

        vm.startPrank(user1);
        market.claimStableCoinPeg(1);
        vm.stopPrank();
    }

    function testInvestPolicy() public {
        vm.deal(address(market), 10 ether);

        vm.startPrank(user1);
        market.buyMarketPolicyf{value: 1 ether}(expiry, MarketInvest.MarketType.MarketCrash);
        vm.stopPrank();

        vm.startPrank(user1);
        market.investPolicy{value: 1 ether}(1);
        vm.stopPrank();
    }
}
