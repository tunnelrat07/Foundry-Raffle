// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

// creating a contract that creates a subscription to the ChainLinkVRF and adds a consumer
contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;

        // Create a subscription
        (uint256 subId, ) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256, address) {
        console2.log("Creating subscription on chain Id: ", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription(); // creates a subscription and returns the subscription id
        vm.stopBroadcast();
        console2.log("Your subscription id is : ", subId);
        console2.log(
            "Please update your subscription Id in HelperConfig.s.sol"
        );
        return (subId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

// a contract that funds the subscription
contract FundSubscription is Script {
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK -> coz ether and LINK tokens have the same decimal system

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
    }

    function run() public {}
}
