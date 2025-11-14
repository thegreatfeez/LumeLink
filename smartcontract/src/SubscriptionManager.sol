// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {CreatorRegistry} from "./CreatorRegistry.sol";
import {Treasury} from "./Treasury.sol";

contract SubscriptionManager {
    error SubscriptionManager__CreatorDoesNotExist();
    error SubscriptionManager__MinimumSubPriceNotMet();
    error SubscriptionManager__IncorrectPaymentAmount();

    event Subscribed(address indexed subscriber, address indexed creator, uint256 amount, uint256 expiryTime);
    event SubscriptionPriceSet(address indexed creator, uint256 newPrice);

    CreatorRegistry public immutable creatorRegistry;
    Treasury public immutable treasury;

    mapping(address subscriber => mapping(address creator => uint256 expiryTime)) public subscriptions;
    mapping(address creator => uint256 monthlyPrice) public creatorPrices;

    uint256 public constant MINIMUM_SUB_PRICE = 0.001 ether;
    uint256 public constant SUB_DURATION = 30 days;

    constructor(address _creatorRegistry, address _treasury) {
        creatorRegistry = CreatorRegistry(_creatorRegistry);
        treasury = Treasury(_treasury);
    }

    function setSubscriptionPrice(uint256 _price) public {
        if (!creatorRegistry.isCreator(msg.sender)) revert SubscriptionManager__CreatorDoesNotExist();
        if (_price < MINIMUM_SUB_PRICE) revert SubscriptionManager__MinimumSubPriceNotMet();

        creatorPrices[msg.sender] = _price;

        emit SubscriptionPriceSet(msg.sender, _price);
    }

    function subscribe(address _creator) public payable {
        if (!creatorRegistry.isCreator(_creator)) revert SubscriptionManager__CreatorDoesNotExist();
        if (!(creatorPrices[_creator] > 0)) revert SubscriptionManager__MinimumSubPriceNotMet();
        if (msg.value != creatorPrices[_creator]) revert SubscriptionManager__IncorrectPaymentAmount();

        uint256 platformFee = (msg.value * 10) / 100;
        uint256 creatorAmount = msg.value - platformFee;

        if (subscriptions[msg.sender][_creator] < block.timestamp) {
            subscriptions[msg.sender][_creator] = block.timestamp + SUB_DURATION;
        } else {
            subscriptions[msg.sender][_creator] += SUB_DURATION;
        }

        // Send 10% to Treasury with creator tracking
        treasury.receiveFee{value: platformFee}(_creator);

        // Send 90% to creator
        (bool creatorSuccess,) = _creator.call{value: creatorAmount}("");
        require(creatorSuccess, "Creator transfer failed");

        emit Subscribed(msg.sender, _creator, msg.value, subscriptions[msg.sender][_creator]);
    }

    function isSubscribed(address _subscriber, address _creator) external view returns (bool) {
        return subscriptions[_subscriber][_creator] > block.timestamp;
    }

    function getSubscriptionExpiry(address _subscriber, address _creator) external view returns (uint256) {
        return subscriptions[_subscriber][_creator];
    }
}
