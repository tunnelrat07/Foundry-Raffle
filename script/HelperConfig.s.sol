// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    /* VRF Mock Values */
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    /* Errors */
    error HelperConfig__invalidChainId();
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaETHConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__invalidChainId();
        }
    }

    function getSepoliaETHConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether, // 1e16 Wei
                interval: 30, // 30 seconds
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // Chainlink VRF contract of the ETH Sepolia Testnet
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000,
                subscriptionId: 0,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789 // ETH Sepolia link token contract address
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // check to see if we set any Network configs
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // if we havent already set it up lets deploy mocks
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        // for local network we're gonna have to deploy our own fake link token
        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether, // 1e16 Wei
            interval: 30, // 30 seconds
            vrfCoordinator: address(vrfCoordinatorMock), // Chainlink VRF contract of the ETH Sepolia Testnet
            // here gasLane doesnt matter
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 0, // we'll refactor our code such that everytime it sees that the subscription id ==0 , it will programatically create a new subscription and add a valid consumer
            link: address(linkToken)
        });
        return localNetworkConfig;
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
}
