// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {CreatorRegistry} from "./CreatorRegistry.sol";

/**
 * @title SpotlightSelector
 * @notice Selects random creators weekly using Chainlink VRF v2.5 with weighted probability
 * @dev Inherits from VRFConsumerBaseV2Plus for Chainlink VRF v2.5 integration
 */
contract SpotlightSelector is VRFConsumerBaseV2Plus {
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
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    CreatorRegistry private immutable i_creatorRegistry;

    enum SelectionStatus {
        IDLE,
        SELECTING
    }

    address[] private s_currentFeaturedCreators;
    uint256 public constant SELECTION_INTERVAL = 7 days;
    uint256 public constant FEATURED_SLOTS = 5;
    uint256 public lastSelectionTimestamp;
    SelectionStatus private s_selectionStatus;

    struct Selection {
        address[] creators;
        uint256 timestamp;
    }
    Selection[] private s_selectionHistory;

    uint256 private s_requestId;

    uint256 private constant MAX_WEIGHT = 365 days;
    uint256 private constant MIN_WEIGHT = 1;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Initialize the SpotlightSelector contract
     * @param _vrfCoordinator Address of Chainlink VRF Coordinator V2.5
     * @param _subscriptionId Chainlink VRF v2.5 subscription ID (now uint256)
     * @param _keyHash Gas lane key hash
     * @param _callbackGasLimit Gas limit for fulfillRandomWords callback
     * @param _creatorRegistry Address of CreatorRegistry contract
     */
    constructor(
        address _vrfCoordinator,
        uint256 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        address _creatorRegistry
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
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
     * @dev Initiates Chainlink VRF v2.5 request for random number
     */
    function requestRandomWinner() external returns (uint256) {
        if (lastSelectionTimestamp != 0 && block.timestamp < lastSelectionTimestamp + SELECTION_INTERVAL) {
            revert SpotlightSelector__SelectionTooSoon();
        }

        if (s_selectionStatus == SelectionStatus.SELECTING) {
            revert SpotlightSelector__AlreadySelecting();
        }

        if (!_hasEnoughCreators()) {
            revert SpotlightSelector__NoCreatorsRegistered();
        }

        s_selectionStatus = SelectionStatus.SELECTING;

        
        s_requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay in native tokens (ETH on Base)
                    // Set to false to pay in LINK tokens
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        emit SelectionRequested(s_requestId, block.timestamp);
        return s_requestId;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getCurrentFeatured() external view returns (address[] memory) {
        return s_currentFeaturedCreators;
    }

    function getSelectionHistory(uint256 index) external view returns (Selection memory) {
        return s_selectionHistory[index];
    }

    function getSelectionHistoryLength() external view returns (uint256) {
        return s_selectionHistory.length;
    }

    function canRequestSelection() external view returns (bool) {
        return (lastSelectionTimestamp == 0 || block.timestamp >= lastSelectionTimestamp + SELECTION_INTERVAL)
            && s_selectionStatus == SelectionStatus.IDLE && _hasEnoughCreators();
    }

    function getSelectionStatus() external view returns (SelectionStatus) {
        return s_selectionStatus;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Chainlink VRF v2.5 callback with random number
     * @dev Called by Chainlink VRF Coordinator with random number
     * @param requestId The request ID from VRF
     * @param randomWords Array of random numbers (we use first one)
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        if (requestId != s_requestId) {
            revert SpotlightSelector__InvalidRequestId();
        }

        address[] memory selectedCreators = _selectWeightedCreators(randomWords[0]);

        s_currentFeaturedCreators = selectedCreators;
        lastSelectionTimestamp = block.timestamp;
        s_selectionStatus = SelectionStatus.IDLE;

        for (uint256 i = 0; i < selectedCreators.length; i++) {
            i_creatorRegistry.updateLastFeatured(selectedCreators[i]);
        }

        s_selectionHistory.push(Selection({creators: selectedCreators, timestamp: block.timestamp}));

        emit CreatorsSelected(selectedCreators, block.timestamp);
    }

    function _selectWeightedCreators(uint256 randomSeed) private view returns (address[] memory) {
        address[] memory allCreators = i_creatorRegistry.getAllCreators();
        uint256 totalCreators = allCreators.length;

        uint256 slotsToFill = totalCreators < FEATURED_SLOTS ? totalCreators : FEATURED_SLOTS;

        uint256[] memory weights = new uint256[](totalCreators);
        uint256 totalWeight = 0;

        for (uint256 i = 0; i < totalCreators; i++) {
            uint256 lastFeatured = i_creatorRegistry.getLastFeaturedTimestamp(allCreators[i]);

            if (lastFeatured == 0) {
                weights[i] = MAX_WEIGHT;
            } else {
                uint256 timeSinceFeatured = block.timestamp - lastFeatured;
                weights[i] = timeSinceFeatured > MAX_WEIGHT ? MAX_WEIGHT : timeSinceFeatured;
                if (weights[i] < MIN_WEIGHT) weights[i] = MIN_WEIGHT;
            }

            totalWeight += weights[i];
        }

        address[] memory selected = new address[](slotsToFill);
        bool[] memory isSelected = new bool[](totalCreators);

        for (uint256 i = 0; i < slotsToFill; i++) {
            uint256 randomValue = uint256(keccak256(abi.encode(randomSeed, i))) % totalWeight;

            uint256 cumulativeWeight = 0;
            for (uint256 j = 0; j < totalCreators; j++) {
                if (isSelected[j]) continue;

                cumulativeWeight += weights[j];

                if (randomValue < cumulativeWeight) {
                    selected[i] = allCreators[j];
                    isSelected[j] = true;
                    totalWeight -= weights[j];
                    break;
                }
            }
        }

        return selected;
    }

    function _hasEnoughCreators() private view returns (bool) {
        return i_creatorRegistry.getCreatorCount() > 0;
    }
}