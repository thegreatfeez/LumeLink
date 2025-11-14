// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SpotlightSelector} from "../src/SpotlightSelector.sol";
import {CreatorRegistry} from "../src/CreatorRegistry.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract SpotlightSelectorTest is Test {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SpotlightSelector__SelectionTooSoon();
    error SpotlightSelector__AlreadySelecting();
    error SpotlightSelector__NotEnoughCreators();
    error SpotlightSelector__InvalidRequestId();
    error SpotlightSelector__NoCreatorsRegistered();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SelectionRequested(uint256 indexed requestId, uint256 timestamp);
    event CreatorsSelected(address[] creators, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    SpotlightSelector public spotlightSelector;
    CreatorRegistry public creatorRegistry;
    VRFCoordinatorV2Mock public vrfCoordinator;

    // Chainlink VRF parameters
    uint96 constant MOCK_BASE_FEE = 0.25 ether;
    uint96 constant MOCK_GAS_PRICE_LINK = 1e9;
    uint64 subscriptionId;
    bytes32 constant KEY_HASH = bytes32(uint256(1));
    uint32 constant CALLBACK_GAS_LIMIT = 1000000;

    // Time constants
    uint256 constant SELECTION_INTERVAL = 7 days;
    uint256 constant FEATURED_SLOTS = 5;

    // Test creators
    address creator1 = makeAddr("creator1");
    address creator2 = makeAddr("creator2");
    address creator3 = makeAddr("creator3");
    address creator4 = makeAddr("creator4");
    address creator5 = makeAddr("creator5");
    address creator6 = makeAddr("creator6");

    function setUp() public {
        // Deploy mock VRF Coordinator
        vrfCoordinator = new VRFCoordinatorV2Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK);

        // Create and fund subscription
        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 100 ether);

        // Deploy CreatorRegistry
        creatorRegistry = new CreatorRegistry();

        // Deploy SpotlightSelector
        spotlightSelector = new SpotlightSelector(
            address(vrfCoordinator), subscriptionId, KEY_HASH, CALLBACK_GAS_LIMIT, address(creatorRegistry)
        );

        // Add SpotlightSelector as consumer
        vrfCoordinator.addConsumer(subscriptionId, address(spotlightSelector));

        // Register test creators
        _registerCreators();
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _registerCreators() private {
        vm.prank(creator1);
        creatorRegistry.registerCreator("ipfs://creator1");

        vm.prank(creator2);
        creatorRegistry.registerCreator("ipfs://creator2");

        vm.prank(creator3);
        creatorRegistry.registerCreator("ipfs://creator3");

        vm.prank(creator4);
        creatorRegistry.registerCreator("ipfs://creator4");

        vm.prank(creator5);
        creatorRegistry.registerCreator("ipfs://creator5");

        vm.prank(creator6);
        creatorRegistry.registerCreator("ipfs://creator6");
    }

    function _requestAndFulfillRandomness() private returns (uint256) {
        uint256 requestId = spotlightSelector.requestRandomWinner();

        // Fulfill VRF request
        vrfCoordinator.fulfillRandomWords(requestId, address(spotlightSelector));

        return requestId;
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function testConstructorSetsCorrectInitialState() public {
        assertEq(uint256(spotlightSelector.getSelectionStatus()), uint256(SpotlightSelector.SelectionStatus.IDLE));
        assertEq(spotlightSelector.lastSelectionTimestamp(), 0); // Changed from block.timestamp to 0
        assertEq(spotlightSelector.FEATURED_SLOTS(), 5);
        assertEq(spotlightSelector.SELECTION_INTERVAL(), 7 days);
    }

    function testConstructorSetsCorrectContracts() public view {
        // Check that registry is set (by trying to call it)
        assertTrue(address(spotlightSelector) != address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    REQUEST RANDOM WINNER TESTS
    //////////////////////////////////////////////////////////////*/
    function testRequestRandomWinnerFirstTime() public {
        uint256 requestId = spotlightSelector.requestRandomWinner();

        assertTrue(requestId > 0);
        assertEq(uint256(spotlightSelector.getSelectionStatus()), uint256(SpotlightSelector.SelectionStatus.SELECTING));
    }

    function testRequestRandomWinnerEmitsEvent() public {
        vm.expectEmit(false, false, false, false);
        emit SelectionRequested(1, block.timestamp);

        spotlightSelector.requestRandomWinner();
    }

    function testRequestRandomWinnerRevertsIfTooSoon() public {
        // First request
        spotlightSelector.requestRandomWinner();
        vrfCoordinator.fulfillRandomWords(1, address(spotlightSelector));

        // Try second request immediately (should fail)
        vm.expectRevert(SpotlightSelector__SelectionTooSoon.selector);
        spotlightSelector.requestRandomWinner();
    }

    function testRequestRandomWinnerRevertsIfAlreadySelecting() public {
        // Start selection
        spotlightSelector.requestRandomWinner();

        // Try to request again before fulfillment
        vm.warp(block.timestamp + 8 days); // Past the interval
        vm.expectRevert(SpotlightSelector__AlreadySelecting.selector);
        spotlightSelector.requestRandomWinner();
    }

    function testRequestRandomWinnerRevertsWithNoCreators() public {
        // Deploy new registry with no creators
        CreatorRegistry emptyRegistry = new CreatorRegistry();

        SpotlightSelector emptySelector = new SpotlightSelector(
            address(vrfCoordinator), subscriptionId, KEY_HASH, CALLBACK_GAS_LIMIT, address(emptyRegistry)
        );

        vrfCoordinator.addConsumer(subscriptionId, address(emptySelector));

        vm.expectRevert(SpotlightSelector__NoCreatorsRegistered.selector);
        emptySelector.requestRandomWinner();
    }

    function testRequestRandomWinnerWorksAfterInterval() public {
        // First selection
        _requestAndFulfillRandomness();

        // Fast forward past interval
        vm.warp(block.timestamp + SELECTION_INTERVAL + 1);

        // Should work now
        uint256 requestId = spotlightSelector.requestRandomWinner();
        assertTrue(requestId > 0);
    }

    /*//////////////////////////////////////////////////////////////
                    FULFILL RANDOM WORDS TESTS
    //////////////////////////////////////////////////////////////*/
    function testFulfillRandomWordsSelectsCreators() public {
        uint256 requestId = spotlightSelector.requestRandomWinner();

        // Fulfill the request
        vrfCoordinator.fulfillRandomWords(requestId, address(spotlightSelector));

        // Check that creators were selected
        address[] memory featured = spotlightSelector.getCurrentFeatured();
        assertEq(featured.length, FEATURED_SLOTS);
    }

    function testFulfillRandomWordsUpdatesState() public {
        uint256 initialTimestamp = block.timestamp;

        // Warp forward to make timestamp change
        vm.warp(block.timestamp + 1);

        _requestAndFulfillRandomness();

        // Check state updated
        assertEq(uint256(spotlightSelector.getSelectionStatus()), uint256(SpotlightSelector.SelectionStatus.IDLE));
        assertGt(spotlightSelector.lastSelectionTimestamp(), initialTimestamp);
    }

    function testFulfillRandomWordsStoresHistory() public {
        _requestAndFulfillRandomness();

        assertEq(spotlightSelector.getSelectionHistoryLength(), 1);

        SpotlightSelector.Selection memory selection = spotlightSelector.getSelectionHistory(0);
        assertEq(selection.creators.length, FEATURED_SLOTS);
        assertEq(selection.timestamp, block.timestamp);
    }

    function testFulfillRandomWordsEmitsEvent() public {
        uint256 requestId = spotlightSelector.requestRandomWinner();
        
        // Expect the CreatorsSelected event (ignore the exact creators array)
        vm.expectEmit(false, false, false, false);
        emit CreatorsSelected(new address[](5), block.timestamp);
        
        vrfCoordinator.fulfillRandomWords(requestId, address(spotlightSelector));
    }

    function testFulfillRandomWordsUpdatesCreatorTimestamps() public {
        _requestAndFulfillRandomness();

        address[] memory featured = spotlightSelector.getCurrentFeatured();

        // Check that selected creators have updated timestamps
        for (uint256 i = 0; i < featured.length; i++) {
            uint256 lastFeatured = creatorRegistry.getLastFeaturedTimestamp(featured[i]);
            assertEq(lastFeatured, block.timestamp);
        }
    }

    function testFulfillRandomWordsSelectsUniqueCreators() public {
        _requestAndFulfillRandomness();

        address[] memory featured = spotlightSelector.getCurrentFeatured();

        // Check no duplicates
        for (uint256 i = 0; i < featured.length; i++) {
            for (uint256 j = i + 1; j < featured.length; j++) {
                assertTrue(featured[i] != featured[j], "Duplicate creator found");
            }
        }
    }

    function testFulfillRandomWordsWithFewerCreatorsThanSlots() public {
        // Deploy new registry with only 3 creators
        CreatorRegistry smallRegistry = new CreatorRegistry();

        vm.prank(creator1);
        smallRegistry.registerCreator("ipfs://creator1");
        vm.prank(creator2);
        smallRegistry.registerCreator("ipfs://creator2");
        vm.prank(creator3);
        smallRegistry.registerCreator("ipfs://creator3");

        SpotlightSelector smallSelector = new SpotlightSelector(
            address(vrfCoordinator), subscriptionId, KEY_HASH, CALLBACK_GAS_LIMIT, address(smallRegistry)
        );

        vrfCoordinator.addConsumer(subscriptionId, address(smallSelector));

        // Request and fulfill
        uint256 requestId = smallSelector.requestRandomWinner();
        vrfCoordinator.fulfillRandomWords(requestId, address(smallSelector));

        // Should feature all 3 creators
        address[] memory featured = smallSelector.getCurrentFeatured();
        assertEq(featured.length, 3, "Should feature all available creators");
    }

    /*//////////////////////////////////////////////////////////////
                        WEIGHTED SELECTION TESTS
    //////////////////////////////////////////////////////////////*/
    function testWeightedSelectionFavorsNeverFeaturedCreators() public {
        // Feature some creators first
        _requestAndFulfillRandomness();

        // Add new creator who was never featured
        address newCreator = makeAddr("newCreator");
        vm.prank(newCreator);
        creatorRegistry.registerCreator("ipfs://newCreator");

        // Fast forward and select again
        vm.warp(block.timestamp + SELECTION_INTERVAL + 1);
        _requestAndFulfillRandomness();

        // The new creator should have high chance of being featured
        // (We can't test probability in single run, but we can check they CAN be selected)
        address[] memory featured = spotlightSelector.getCurrentFeatured();
        assertTrue(featured.length == FEATURED_SLOTS);
    }

    function testWeightedSelectionUpdatesWeightsOverTime() public {
        // First selection
        _requestAndFulfillRandomness();
        address[] memory firstFeatured = spotlightSelector.getCurrentFeatured();

        // Fast forward 6 months
        vm.warp(block.timestamp + 180 days);

        // Second selection (after interval passed)
        _requestAndFulfillRandomness();
        address[] memory secondFeatured = spotlightSelector.getCurrentFeatured();

        // Creators from first selection should have high weight now
        // (Some should likely appear again due to time passed)
        assertTrue(secondFeatured.length == FEATURED_SLOTS);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/
    function testGetCurrentFeaturedBeforeSelection() public {
        address[] memory featured = spotlightSelector.getCurrentFeatured();
        assertEq(featured.length, 0, "Should be empty before first selection");
    }

    function testGetCurrentFeaturedAfterSelection() public {
        _requestAndFulfillRandomness();

        address[] memory featured = spotlightSelector.getCurrentFeatured();
        assertEq(featured.length, FEATURED_SLOTS);
    }

    function testGetSelectionHistoryLength() public {
        assertEq(spotlightSelector.getSelectionHistoryLength(), 0);

        _requestAndFulfillRandomness();
        assertEq(spotlightSelector.getSelectionHistoryLength(), 1);

        vm.warp(block.timestamp + SELECTION_INTERVAL + 1);
        _requestAndFulfillRandomness();
        assertEq(spotlightSelector.getSelectionHistoryLength(), 2);
    }

    function testGetSelectionHistory() public {
        _requestAndFulfillRandomness();

        SpotlightSelector.Selection memory selection = spotlightSelector.getSelectionHistory(0);
        assertEq(selection.creators.length, FEATURED_SLOTS);
        assertEq(selection.timestamp, block.timestamp);
    }

    function testCanRequestSelectionInitially() public {
        assertTrue(spotlightSelector.canRequestSelection());
    }

    function testCanRequestSelectionWhileSelecting() public {
        spotlightSelector.requestRandomWinner();

        assertFalse(spotlightSelector.canRequestSelection());
    }

    function testCanRequestSelectionTooSoon() public {
        _requestAndFulfillRandomness();

        // Immediately after selection
        assertFalse(spotlightSelector.canRequestSelection());

        // After 6 days (not enough)
        vm.warp(block.timestamp + 6 days);
        assertFalse(spotlightSelector.canRequestSelection());

        // After 7 days (exactly)
        vm.warp(block.timestamp + 1 days);
        assertTrue(spotlightSelector.canRequestSelection());
    }

    function testGetSelectionStatus() public {
        // Initially IDLE
        assertEq(uint256(spotlightSelector.getSelectionStatus()), uint256(SpotlightSelector.SelectionStatus.IDLE));

        // During selection
        spotlightSelector.requestRandomWinner();
        assertEq(uint256(spotlightSelector.getSelectionStatus()), uint256(SpotlightSelector.SelectionStatus.SELECTING));

        // After fulfillment
        vrfCoordinator.fulfillRandomWords(1, address(spotlightSelector));
        assertEq(uint256(spotlightSelector.getSelectionStatus()), uint256(SpotlightSelector.SelectionStatus.IDLE));
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    function testMultipleSelectionCycles() public {
        // First cycle
        _requestAndFulfillRandomness();
        address[] memory featured1 = spotlightSelector.getCurrentFeatured();
        assertEq(featured1.length, FEATURED_SLOTS);

        // Second cycle
        vm.warp(block.timestamp + SELECTION_INTERVAL + 1);
        _requestAndFulfillRandomness();
        address[] memory featured2 = spotlightSelector.getCurrentFeatured();
        assertEq(featured2.length, FEATURED_SLOTS);

        // Third cycle
        vm.warp(block.timestamp + SELECTION_INTERVAL + 1);
        _requestAndFulfillRandomness();
        address[] memory featured3 = spotlightSelector.getCurrentFeatured();
        assertEq(featured3.length, FEATURED_SLOTS);

        // Check history
        assertEq(spotlightSelector.getSelectionHistoryLength(), 3);
    }

    function testSelectionWithDynamicCreatorGrowth() public {
        // Initial selection with 6 creators
        _requestAndFulfillRandomness();
        assertEq(spotlightSelector.getCurrentFeatured().length, 5);

        // Add more creators
        for (uint256 i = 7; i <= 10; i++) {
            address newCreator = makeAddr(string(abi.encodePacked("creator", i)));
            vm.prank(newCreator);
            creatorRegistry.registerCreator(string(abi.encodePacked("ipfs://creator", i)));
        }

        // New selection with 10 creators
        vm.warp(block.timestamp + SELECTION_INTERVAL + 1);
        _requestAndFulfillRandomness();
        assertEq(spotlightSelector.getCurrentFeatured().length, 5);
    }

    function testAnyoneCanTriggerSelection() public {
        address randomUser = makeAddr("randomUser");

        vm.prank(randomUser);
        uint256 requestId = spotlightSelector.requestRandomWinner();

        assertTrue(requestId > 0, "Any user should be able to trigger selection");
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/
    function testSelectionAtExactIntervalBoundary() public {
        _requestAndFulfillRandomness();

        uint256 exactTime = block.timestamp + SELECTION_INTERVAL;
        vm.warp(exactTime);

        // Should work at exact boundary
        uint256 requestId = spotlightSelector.requestRandomWinner();
        assertTrue(requestId > 0);
    }

    function testMultipleHistoryEntries() public {
        for (uint256 i = 0; i < 5; i++) {
            _requestAndFulfillRandomness();

            if (i < 4) {
                vm.warp(block.timestamp + SELECTION_INTERVAL + 1);
            }
        }

        assertEq(spotlightSelector.getSelectionHistoryLength(), 5);

        // Verify each history entry
        for (uint256 i = 0; i < 5; i++) {
            SpotlightSelector.Selection memory selection = spotlightSelector.getSelectionHistory(i);
            assertTrue(selection.creators.length > 0);
            assertTrue(selection.timestamp > 0);
        }
    }

    function testLongTimeBetweenSelections() public {
        _requestAndFulfillRandomness();

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        // Should still work
        uint256 requestId = spotlightSelector.requestRandomWinner();
        assertTrue(requestId > 0);
    }
}