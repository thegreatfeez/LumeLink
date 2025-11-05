// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {CreatorRegistry} from "/src/CreatorRegistry.sol";

contract SubscriptionManager {
    error SubscriptionManager__CreatorDoesNotExist();
    error SubscriptionManager__MinimumSubPriceNotMet();
    error SubscriptionManager__IncorrectPaymentAmount();

    event Subscribed(address indexed subscriber, address indexed creator, uint256 amount, uint256 expiryTime);
    event SubscriptionPriceSet(address indexed creator, uint256 newPrice);

    CreatorRegistry public immutable creatorRegistry;
    address public immutable treasury;

    mapping(address subscriber => mapping(address creator => uint256 expiryTime)) public subscriptions;
    mapping(address creator => uint256 monthlyPrice) public creatorPrices;

    uint256 public constant MINIMUM_SUB_PRICE = 0.001 ether;
    uint256 public constant SUB_DURATION = 30 days;

    constructor(address _creatorRegistry, address _treasury) {
        creatorRegistry = CreatorRegistry(_creatorRegistry);
        treasury = _treasury;
    }

    /* **Key Functions:**
    1. `setSubscriptionPrice(uint256 _price)` - Creator sets their monthly price
    2. `subscribe(address _creator)` - User subscribes, pays, gets 30 days
    3. `isSubscribed(address _subscriber, address _creator)` - Check active subscription
    4. `getSubscriptionExpiry(...)` - View when subscription ends

    ### **Payment Flow in `subscribe()`:**
    ```
    1. Check creator exists (call CreatorRegistry)
    2. Check msg.value == creator's price
    3. Calculate expiry (block.timestamp + 30 days)
    4. Store subscription
    5. Send 10% to Treasury
    6. Send 90% to Creator
    7. Emit event
    */

    function setSubscriptionPrice(uint256 _price) public {

        if(!creatorRegistry.isCreator(msg.sender)) revert SubscriptionManager__CreatorDoesNotExist();
        if(_price < MINIMUM_SUB_PRICE) revert SubscriptionManager__MinimumSubPriceNotMet();

        creatorPrices[msg.sender] = _price;

        emit SubscriptionPriceSet(msg.sender, _price);
    }
}
