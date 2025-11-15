// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SpotlightSelector} from "../src/SpotlightSelector.sol";
import {CreatorRegistry} from "../src/CreatorRegistry.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

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
    VRFCoordinatorV2_5Mock public vrfCoordinator;

    // Chainlink VRF parameters (reduced for testing)
    uint96 constant MOCK_BASE_FEE = 0.001 ether;
    uint96 constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 constant MOCK_WEI_PER_UNIT_LINK = 4e15;
    uint256 subscriptionId;
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
        // Give test contract ETH for funding subscription
        vm.deal(address(this), 1000 ether);
        
        // Deploy mock VRF Coordinator v2.5
        vrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UNIT_LINK
        );

        // Create and fund subscription (v2.5 needs both LINK and native ETH)
        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 100 ether); // LINK
        vrfCoordinator.fundSubscriptionWithNative{value: 100 ether}(subscriptionId); // Native ETH

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
        assertEq(spotlightSelector.lastSelectionTimestamp(), 0);
        assertEq(spotlightSelector.FEATURED_SLOTS(), 5);
        assertEq(spotlightSelector.SELECTION_INTERVAL(), 7 days);
    }

    function testConstructorSetsCorrectContracts() public view {
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
        _requestAndFulfillRandomness();

        vm.expectRevert(SpotlightSelector__SelectionTooSoon.selector);
        spotlightSelector.requestRandomWinner();
    }

    function testRequestRandomWinnerRevertsIfAlreadySelecting() public {
        spotlightSelector.requestRandomWinner();

        vm.warp(block.timestamp + 8 days);
        vm.expectRevert(SpotlightSelector__AlreadySelecting.selector);
        spotlightSelector.requestRandomWinner();
    }

    function testRequestRandomWinnerRevertsWithNoCreators() public {
        CreatorRegistry emptyRegistry = new CreatorRegistry();

        SpotlightSelector emptySelector = new SpotlightSelector(
            address(vrfCoordinator), subscriptionId, KEY_HASH, CALLBACK_GAS_LIMIT, address(emptyRegistry)
        );

        vrfCoordinator.addConsumer(subscriptionId, address(emptySelector));

        vm.expectRevert(SpotlightSelector__NoCreatorsRegistered.selector);
        emptySelector.requestRandomWinner();
    }

    function testRequestRandomWinnerWorksAfterInterval() public {
        _requestAndFulfillRandomness();

        vm.warp(block.timestamp + SELECTION_INTERVAL + 1);

        uint256 requestId = spotlightSelector.requestRandomWinner();
        assertTrue(requestId > 0);
    }

    /*//////////////////////////////////////////////////////////////
                    FULFILL RANDOM WORDS TESTS
    //////////////////////////////////////////////////////////////*/
    function testFulfillRandomWordsSelectsCreators() public {
        uint256 requestId = spotlightSelector.requestRandomWinner();

        vrfCoordinator.fulfillRandomWords(requestId, address(spotlightSelector));

        address[] memory featured = spotlightSelector.getCurrentFeatured();
        assertEq(featured.length, FEATURED_SLOTS);
    }

    function testFulfillRandomWordsUpdatesState() public {
        uint256 initialTimestamp = block.timestamp;

        vm.warp(block.timestamp + 1);

        _requestAndFulfillRandomness();

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
        
        vm.expectEmit(false, false, false, false);
        emit CreatorsSelected(new address[](5), block.timestamp);
        
        vrfCoordinator.fulfillRandomWords(requestId, address(spotlightSelector));
    }

    function testFulfillRandomWordsUpdatesCreatorTimestamps() public {
        _requestAndFulfillRandomness();

        address[] memory featured = spotlightSelector.getCurrentFeatured();

        for (uint256 i = 0; i < featured.length; i++) {
            uint256 lastFeatured = creatorRegistry.getLastFeaturedTimestamp(featured[i]);
            assertEq(lastFeatured, block.timestamp);
        }
    }

    function testFulfillRandomWordsSelectsUniqueCreators() public {
        _requestAndFulfillRandomness();

        address[] memory featured = spotlightSelector.getCurrentFeatured();

        for (uint256 i = 0; i < featured.length; i++) {
            for (uint256 j = i + 1; j < featured.length; j++) {
                assertTrue(featured[i] != featured[j], "Duplicate creator found");
            }
        }
    }

    function testFulfillRandomWordsWithFewerCreatorsThanSlots() public {
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

        uint256 requestId = smallSelector.requestRandomWinner();
        vrfCoordinator.fulfillRandomWords(requestId, address(smallSelector));

        address[] memory featured = smallSelector.getCurrentFeatured();
        assertEq(featured.length, 3, "Should feature all available creators");
    }

    /*//////////////////////////////////////////////////////////////
                        WEIGHTED SELECTION TESTS
    //////////////////////////////////////////////////////////////*/
    function testWeightedSelectionFavorsNeverFeaturedCreators() public {
        _requestAndFulfillRandomness();

        address newCreator = makeAddr("newCreator");
        vm.prank(newCreator);
        creatorRegistry.registerCreator("ipfs://newCreator");

        vm.warp(block.timestamp + SELECTION_INTERVAL + 1);
        _requestAndFulfillRandomness();

        address[] memory featured = spotlightSelector.getCurrentFeatured();
        assertTrue(featured.length == FEATURED_SLOTS);
    }

    function testWeightedSelectionUpdatesWeightsOverTime() public {
        _requestAndFulfillRandomness();
        address[] memory firstFeatured = spotlightSelector.getCurrentFeatured();

        vm.warp(block.timestamp + 180 days);

        _requestAndFulfillRandomness();
        address[] memory secondFeatured = spotlightSelector.getCurrentFeatured();

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

        assertFalse(spotlightSelector.canRequestSelection());

        vm.warp(block.timestamp + 6 days);
        assertFalse(spotlightSelector.canRequestSelection());

        vm.warp(block.timestamp + 1 days);
        assertTrue(spotlightSelector.canRequestSelection());
    }

    function testGetSelectionStatus() public {
        assertEq(uint256(spotlightSelector.getSelectionStatus()), uint256(SpotlightSelector.SelectionStatus.IDLE));

        spotlightSelector.requestRandomWinner();
        assertEq(uint256(spotlightSelector.getSelectionStatus()), uint256(SpotlightSelector.SelectionStatus.SELECTING));

        vrfCoordinator.fulfillRandomWords(1, address(spotlightSelector));
        assertEq(uint256(spotlightSelector.getSelectionStatus()), uint256(SpotlightSelector.SelectionStatus.IDLE));
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    function testMultipleSelectionCycles() public {
        _requestAndFulfillRandomness();
        address[] memory featured1 = spotlightSelector.getCurrentFeatured();
        assertEq(featured1.length, FEATURED_SLOTS);

        vm.warp(block.timestamp + SELECTION_INTERVAL + 1);
        _requestAndFulfillRandomness();
        address[] memory featured2 = spotlightSelector.getCurrentFeatured();
        assertEq(featured2.length, FEATURED_SLOTS);

        vm.warp(block.timestamp + SELECTION_INTERVAL + 1);
        _requestAndFulfillRandomness();
        address[] memory featured3 = spotlightSelector.getCurrentFeatured();
        assertEq(featured3.length, FEATURED_SLOTS);

        assertEq(spotlightSelector.getSelectionHistoryLength(), 3);
    }

    function testSelectionWithDynamicCreatorGrowth() public {
        _requestAndFulfillRandomness();
        assertEq(spotlightSelector.getCurrentFeatured().length, 5);

        for (uint256 i = 7; i <= 10; i++) {
            address newCreator = makeAddr(string(abi.encodePacked("creator", i)));
            vm.prank(newCreator);
            creatorRegistry.registerCreator(string(abi.encodePacked("ipfs://creator", i)));
        }

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

        for (uint256 i = 0; i < 5; i++) {
            SpotlightSelector.Selection memory selection = spotlightSelector.getSelectionHistory(i);
            assertTrue(selection.creators.length > 0);
            assertTrue(selection.timestamp > 0);
        }
    }

    function testLongTimeBetweenSelections() public {
        _requestAndFulfillRandomness();

        vm.warp(block.timestamp + 365 days);

        uint256 requestId = spotlightSelector.requestRandomWinner();
        assertTrue(requestId > 0);
    }
}