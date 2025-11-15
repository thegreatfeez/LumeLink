// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    // Mock configuration for local testing
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15; // 0.004 ETH per LINK

    // Chain IDs
    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    struct NetworkConfig {
        address vrfCoordinator;
        uint256 subscriptionId;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        address linkToken;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == BASE_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getBaseSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    /**
     * @notice Get Base Sepolia testnet configuration
     * @dev Uses real Chainlink VRF v2.5 contracts on Base Sepolia
     */
    function getBaseSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            // VRF Coordinator v2.5 for Base Sepolia
            vrfCoordinator: 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE,
            // YOUR subscription ID (the big one!)
            subscriptionId: 6856904613366688233394896328050563800370039002518480924542370413492177404693,
            // Key Hash for Base Sepolia
            keyHash: 0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71,
            // Gas limit for your fulfillRandomWords callback
            // Adjust based on complexity - your logic is moderate
            callbackGasLimit: 500000,
            // LINK token on Base Sepolia
            linkToken: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410
        });
    }

    /**
     * @notice Get or create local Anvil configuration with mocks
     * @dev Deploys mock VRF Coordinator and LINK token for testing
     */
    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        // Return existing config if already set
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        // Deploy mocks
        vm.startBroadcast();
        
        // Deploy VRF Coordinator v2.5 Mock
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UNIT_LINK
        );
        
        // Deploy mock LINK token
        LinkToken linkToken = new LinkToken();
        
        vm.stopBroadcast();

        return NetworkConfig({
            vrfCoordinator: address(vrfCoordinator),
            subscriptionId: 0,
            keyHash: 0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71,
            callbackGasLimit: 500000,
            linkToken: address(linkToken)
        });
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}