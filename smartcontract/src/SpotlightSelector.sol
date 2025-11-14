// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {CreatorRegistry} from "./CreatorRegistry.sol";

/**
 * @title SpotlightSelector
 * @notice Selects random creators weekly using Chainlink VRF with weighted probability based on time since last featured
 * @dev Inherits from VRFConsumerBaseV2 for Chainlink VRF integration
 */
contract SpotlightSelector is VRFConsumerBaseV2 {
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
                         CHAINLINK VRF CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1; // We need 1 random number

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    CreatorRegistry private immutable i_creatorRegistry;

    // Selection state
    enum SelectionStatus {
        IDLE,
        SELECTING
    }

    address[] private s_currentFeaturedCreators;
    uint256 public constant SELECTION_INTERVAL = 7 days;
    uint256 public constant FEATURED_SLOTS = 5;
    uint256 public lastSelectionTimestamp;
    SelectionStatus private s_selectionStatus;

    // History tracking
    struct Selection {
        address[] creators;
        uint256 timestamp;
    }
    Selection[] private s_selectionHistory;

    // Request tracking
    uint256 private s_requestId;

    // Weight configuration
    uint256 private constant MAX_WEIGHT = 365 days; // Never featured creators get this weight
    uint256 private constant MIN_WEIGHT = 1; // Recently featured creators get low weight

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Initialize the SpotlightSelector contract
     * @param _vrfCoordinator Address of Chainlink VRF Coordinator
     * @param _subscriptionId Chainlink VRF subscription ID
     * @param _keyHash Gas lane key hash
     * @param _callbackGasLimit Gas limit for fulfillRandomWords callback
     * @param _creatorRegistry Address of CreatorRegistry contract
     */
    constructor(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        address _creatorRegistry
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_subscriptionId = _subscriptionId;
        i_keyHash = _keyHash;
        i_callbackGasLimit = _callbackGasLimit;
        i_creatorRegistry = CreatorRegistry(_creatorRegistry);

        s_selectionStatus = SelectionStatus.IDLE;
        lastSelectionTimestamp = 0;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Request random selection of creators (callable by anyone after 7 days)
     * @dev Initiates Chainlink VRF request for random number
     */
    function requestRandomWinner() external returns (uint256) {
        // Check: Enough time passed (7 days), except for first selection (lastSelectionTimestamp == 0)
        if (lastSelectionTimestamp != 0 && block.timestamp < lastSelectionTimestamp + SELECTION_INTERVAL) {
            revert SpotlightSelector__SelectionTooSoon();
        }

        // Check: Not already selecting
        if (s_selectionStatus == SelectionStatus.SELECTING) {
            revert SpotlightSelector__AlreadySelecting();
        }

        // Check: At least some creators registered
        if (!_hasEnoughCreators()) {
            revert SpotlightSelector__NoCreatorsRegistered();
        }

        // Set status to SELECTING
        s_selectionStatus = SelectionStatus.SELECTING;

        // Request random number from Chainlink VRF
        s_requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );

        emit SelectionRequested(s_requestId, block.timestamp);
        return s_requestId;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Get currently featured creators
     * @return Array of currently featured creator addresses
     */
    function getCurrentFeatured() external view returns (address[] memory) {
        return s_currentFeaturedCreators;
    }

    /**
     * @notice Get selection history by index
     * @param index Index in selection history array
     * @return Selection struct containing creators and timestamp
     */
    function getSelectionHistory(uint256 index) external view returns (Selection memory) {
        return s_selectionHistory[index];
    }

    /**
     * @notice Get total number of selections in history
     * @return Number of past selections
     */
    function getSelectionHistoryLength() external view returns (uint256) {
        return s_selectionHistory.length;
    }

    /**
     * @notice Check if selection can be requested
     * @return True if enough time has passed and not currently selecting
     */
    function canRequestSelection() external view returns (bool) {
        return (lastSelectionTimestamp == 0 || block.timestamp >= lastSelectionTimestamp + SELECTION_INTERVAL)
            && s_selectionStatus == SelectionStatus.IDLE && _hasEnoughCreators();
    }

    /**
     * @notice Get current selection status
     * @return Current SelectionStatus (IDLE or SELECTING)
     */
    function getSelectionStatus() external view returns (SelectionStatus) {
        return s_selectionStatus;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Chainlink VRF callback with random number
     * @dev Called by Chainlink VRF Coordinator with random number
     * @param requestId The request ID from VRF
     * @param randomWords Array of random numbers (we use first one)
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        // Validate request ID
        if (requestId != s_requestId) {
            revert SpotlightSelector__InvalidRequestId();
        }

        // Get all creators and select weighted random ones
        address[] memory selectedCreators = _selectWeightedCreators(randomWords[0]);

        // Update state
        s_currentFeaturedCreators = selectedCreators;
        lastSelectionTimestamp = block.timestamp;
        s_selectionStatus = SelectionStatus.IDLE;

        // Update lastFeaturedTimestamp for selected creators in CreatorRegistry
        for (uint256 i = 0; i < selectedCreators.length; i++) {
            i_creatorRegistry.updateLastFeatured(selectedCreators[i]);
        }

        // Store in history
        s_selectionHistory.push(Selection({creators: selectedCreators, timestamp: block.timestamp}));

        emit CreatorsSelected(selectedCreators, block.timestamp);
    }

    /**
     * @notice Select creators using weighted random selection
     * @dev Weight = time since last featured (longer = higher chance)
     * @param randomSeed Random number from Chainlink VRF
     * @return Array of selected creator addresses
     */
    function _selectWeightedCreators(uint256 randomSeed) private view returns (address[] memory) {
        // Get all creators from registry
        address[] memory allCreators = i_creatorRegistry.getAllCreators();
        uint256 totalCreators = allCreators.length;

        // If fewer creators than slots, feature all of them
        uint256 slotsToFill = totalCreators < FEATURED_SLOTS ? totalCreators : FEATURED_SLOTS;

        // Calculate weights for all creators
        uint256[] memory weights = new uint256[](totalCreators);
        uint256 totalWeight = 0;

        for (uint256 i = 0; i < totalCreators; i++) {
            uint256 lastFeatured = i_creatorRegistry.getLastFeaturedTimestamp(allCreators[i]);

            if (lastFeatured == 0) {
                // Never featured - give maximum weight
                weights[i] = MAX_WEIGHT;
            } else {
                // Calculate time since last featured
                uint256 timeSinceFeatured = block.timestamp - lastFeatured;
                // Weight increases with time, capped at MAX_WEIGHT
                weights[i] = timeSinceFeatured > MAX_WEIGHT ? MAX_WEIGHT : timeSinceFeatured;
                // Ensure minimum weight
                if (weights[i] < MIN_WEIGHT) weights[i] = MIN_WEIGHT;
            }

            totalWeight += weights[i];
        }

        // Select creators without replacement
        address[] memory selected = new address[](slotsToFill);
        bool[] memory isSelected = new bool[](totalCreators);

        for (uint256 i = 0; i < slotsToFill; i++) {
            // Generate random number for this selection
            uint256 randomValue = uint256(keccak256(abi.encode(randomSeed, i))) % totalWeight;

            // Find the creator at this weighted random position
            uint256 cumulativeWeight = 0;
            for (uint256 j = 0; j < totalCreators; j++) {
                if (isSelected[j]) continue; // Skip already selected creators

                cumulativeWeight += weights[j];

                if (randomValue < cumulativeWeight) {
                    // Found the creator to select
                    selected[i] = allCreators[j];
                    isSelected[j] = true;
                    totalWeight -= weights[j]; // Remove weight from total
                    break;
                }
            }
        }

        return selected;
    }

    /**
     * @notice Check if there are enough creators registered
     * @return True if at least one creator is registered
     */
    function _hasEnoughCreators() private view returns (bool) {
        return i_creatorRegistry.getCreatorCount() > 0;
    }
}
