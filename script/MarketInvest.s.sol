// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/forge-std/src/Script.sol";
import "../src/MarketInvest.sol";

contract MarketInvestScript is Script {
    /// Deploys MarketInvest and optionally performs a sample buyMarketPolicy call.
    /// Environment variables read:
    ///   - PRIVATE_KEY (uint): private key used to broadcast deployment tx
    ///   - AGGREGATOR (address): Chainlink aggregator address (optional)
    ///   - OWNER (address): address to set as owner of the deployed contract (optional)
    ///   - USER_KEY (uint): private key of a user to call buyMarketPolicy (optional)
    function run() external {
        uint256 deployKey = vm.envUint("PRIVATE_KEY");
        address aggregator = vm.envAddress("AGGREGATOR");
        address owner = vm.envAddress("OWNER");

        // Deploy
        vm.startBroadcast(deployKey);
        // If OWNER not provided, use deployer address (vm.addr(deployKey))
        address ownerToUse = owner == address(0) ? vm.addr(deployKey) : owner;
        MarketInvest market = new MarketInvest(aggregator, ownerToUse);
        vm.stopBroadcast();

        // Optional: show the deployed address in logs (via emit or external tooling)
        // You can view the deployed address in the forge output when running with --broadcast -vv

        // Optional: make a sample buyMarketPolicy call from a different account if USER_KEY provided
        uint256 userKey = vm.envUint("USER_KEY");
        if (userKey != 0) {
            // Example expiry 30 days from now
            uint256 expiry = block.timestamp + 30 days;

            // Use MarketCrash enum (index 0). ABI accepts enum as uint8 index.
            vm.startBroadcast(userKey);
            // send 1 ether (MARKET_MONTHLY_SUBSCRIPTION)
            market.buyMarketPolicy{value: 1 ether}(expiry, MarketInvest.MarketType.MarketCrash);
            vm.stopBroadcast();
        }
    }
}