// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CreatorRegistry} from "../src/CreatorRegistry.sol";
import {Treasury} from "../src/Treasury.sol";
import {SubscriptionManager} from "../src/SubscriptionManager.sol";
import {SpotlightSelector} from "../src/SpotlightSelector.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployLumeLink is Script {
    function run() external returns (
        CreatorRegistry,
        Treasury,
        SubscriptionManager,
        SpotlightSelector,
        HelperConfig
    ) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        
        CreatorRegistry creatorRegistry = new CreatorRegistry();
        Treasury treasury = new Treasury();
        SubscriptionManager subscriptionManager = new SubscriptionManager(
            address(creatorRegistry),
            address(treasury)
        );
        SpotlightSelector spotlightSelector = new SpotlightSelector(
            config.vrfCoordinator,
            config.subscriptionId,
            config.keyHash,
            config.callbackGasLimit,
            address(creatorRegistry)
        );
        
        vm.stopBroadcast();

        console.log("=== LumeLink Deployment ===");
        console.log("CreatorRegistry:", address(creatorRegistry));
        console.log("Treasury:", address(treasury));
        console.log("SubscriptionManager:", address(subscriptionManager));
        console.log("SpotlightSelector:", address(spotlightSelector));
        
        return (creatorRegistry, treasury, subscriptionManager, spotlightSelector, helperConfig);
    }
}