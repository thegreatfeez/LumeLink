// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SubscriptionManager} from "../src/SubscriptionManager.sol";
import {CreatorRegistry} from "../src/CreatorRegistry.sol";

contract SubscriptionManagerTest is Test {
    error SubscriptionManager__CreatorDoesNotExist();
    error SubscriptionManager__MinimumSubPriceNotMet();
    error SubscriptionManager__IncorrectPaymentAmount();

    SubscriptionManager public subscriptionManager;
    CreatorRegistry public creatorRegistry;

    string constant METADATA_URI = "https://api.spotchain.com/creator/1";

    address treasury = makeAddr("treasury");
    address creator = makeAddr("creator");
    address subscriber = makeAddr("subscriber");

    uint256 constant SUBSCRIPTION_PRICE = 0.01 ether;
    uint256 constant MINIMUM_SUB_PRICE = 0.001 ether;
    uint256 constant SUB_DURATION = 30 days;

    event Subscribed(address indexed subscriber, address indexed creator, uint256 amount, uint256 expiryTime);
    event SubscriptionPriceSet(address indexed creator, uint256 newPrice);

    function setUp() public {
        creatorRegistry = new CreatorRegistry();
        subscriptionManager = new SubscriptionManager(address(creatorRegistry), treasury);

        vm.deal(creator, 10 ether);
        vm.deal(subscriber, 10 ether);

        vm.prank(creator);
        creatorRegistry.registerCreator(METADATA_URI);
    }

    /*//////////////////////////////////////////////////////////////
                        SUBSCRIPTION PRICE TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetSubscriptionPrice() public {
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);

        uint256 price = subscriptionManager.creatorPrices(creator);
        assertEq(price, SUBSCRIPTION_PRICE);
    }

    function testSetSubscriptionPriceRevertsForNonCreator() public {
        address creator2 = makeAddr("creator2");
        vm.deal(creator2, 10 ether);

        vm.expectRevert(SubscriptionManager__CreatorDoesNotExist.selector);
        vm.prank(creator2);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);
    }

    function testSetSubscriptionPriceRevertsForLowPrice() public {
        vm.expectRevert(SubscriptionManager__MinimumSubPriceNotMet.selector);
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(0.0001 ether);
    }

    function testSetSubscriptionPriceEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit SubscriptionPriceSet(creator, SUBSCRIPTION_PRICE);
        
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);
    }

    function testCreatorCanUpdatePrice() public {
        vm.startPrank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);
        assertEq(subscriptionManager.creatorPrices(creator), SUBSCRIPTION_PRICE);

        subscriptionManager.setSubscriptionPrice(0.02 ether);
        assertEq(subscriptionManager.creatorPrices(creator), 0.02 ether);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            SUBSCRIBE TESTS
    //////////////////////////////////////////////////////////////*/

    function testSubscribe() public {
        
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);

       
        uint256 expectedExpiry = block.timestamp + SUB_DURATION;
        
        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);

        
        assertTrue(subscriptionManager.isSubscribed(subscriber, creator));
        assertEq(subscriptionManager.getSubscriptionExpiry(subscriber, creator), expectedExpiry);
    }

    function testSubscribeRevertsForNonExistentCreator() public {
        address fakeCreator = makeAddr("fakeCreator");
        
        vm.expectRevert(SubscriptionManager__CreatorDoesNotExist.selector);
        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(fakeCreator);
    }

    function testSubscribeRevertsIfCreatorHasNoPrice() public {
        
        vm.expectRevert(SubscriptionManager__MinimumSubPriceNotMet.selector);
        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);
    }

    function testSubscribeRevertsForIncorrectPayment() public {
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);

        vm.expectRevert(SubscriptionManager__IncorrectPaymentAmount.selector);
        vm.prank(subscriber);
        subscriptionManager.subscribe{value: 0.005 ether}(creator); // Wrong amount
    }

    function testSubscribePaymentSplit() public {
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);

        uint256 treasuryBalanceBefore = treasury.balance;
        uint256 creatorBalanceBefore = creator.balance;

        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);

        uint256 expectedPlatformFee = (SUBSCRIPTION_PRICE * 10) / 100; // 10%
        uint256 expectedCreatorAmount = SUBSCRIPTION_PRICE - expectedPlatformFee; // 90%

        assertEq(treasury.balance - treasuryBalanceBefore, expectedPlatformFee);
        assertEq(creator.balance - creatorBalanceBefore, expectedCreatorAmount);
    }

    function testSubscribeEmitsEvent() public {
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);

        uint256 expectedExpiry = block.timestamp + SUB_DURATION;

        vm.expectEmit(true, true, false, true);
        emit Subscribed(subscriber, creator, SUBSCRIPTION_PRICE, expectedExpiry);

        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);
    }

    function testSubscribeExtension() public {
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);

        // First subscription
        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);
        uint256 firstExpiry = subscriptionManager.getSubscriptionExpiry(subscriber, creator);

        // Fast forward 10 days
        vm.warp(block.timestamp + 10 days);

        // Subscribe again (should extend by 30 days from first expiry)
        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);
        uint256 secondExpiry = subscriptionManager.getSubscriptionExpiry(subscriber, creator);

        // Should be first expiry + 30 days (user keeps remaining time)
        assertEq(secondExpiry, firstExpiry + SUB_DURATION);
    }

    function testSubscribeAfterExpiry() public {
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);

        // First subscription
        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);

        // Fast forward past expiry (35 days)
        vm.warp(block.timestamp + 35 days);

        // Check expired
        assertFalse(subscriptionManager.isSubscribed(subscriber, creator));

        // Resubscribe (should start from current time)
        uint256 expectedNewExpiry = block.timestamp + SUB_DURATION;
        
        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);

        assertEq(subscriptionManager.getSubscriptionExpiry(subscriber, creator), expectedNewExpiry);
    }

    function testMultipleSubscribersToOneCreator() public {
        address subscriber2 = makeAddr("subscriber2");
        vm.deal(subscriber2, 10 ether);

        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);

        // First subscriber
        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);

        // Second subscriber
        vm.prank(subscriber2);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);

        // Both should be subscribed
        assertTrue(subscriptionManager.isSubscribed(subscriber, creator));
        assertTrue(subscriptionManager.isSubscribed(subscriber2, creator));
    }

    function testSubscriberToMultipleCreators() public {
        // Create second creator
        address creator2 = makeAddr("creator2");
        vm.deal(creator2, 10 ether);
        
        vm.prank(creator2);
        creatorRegistry.registerCreator("ipfs://creator2");

        // Both creators set prices
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);
        
        vm.prank(creator2);
        subscriptionManager.setSubscriptionPrice(0.02 ether);

        // Subscriber subscribes to both
        vm.startPrank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);
        subscriptionManager.subscribe{value: 0.02 ether}(creator2);
        vm.stopPrank();

        // Check both subscriptions
        assertTrue(subscriptionManager.isSubscribed(subscriber, creator));
        assertTrue(subscriptionManager.isSubscribed(subscriber, creator2));
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testIsSubscribed() public {
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);

        // Before subscription
        assertFalse(subscriptionManager.isSubscribed(subscriber, creator));

        // After subscription
        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);
        assertTrue(subscriptionManager.isSubscribed(subscriber, creator));

        // After expiry
        vm.warp(block.timestamp + SUB_DURATION + 1);
        assertFalse(subscriptionManager.isSubscribed(subscriber, creator));
    }

    function testGetSubscriptionExpiry() public {
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);

        uint256 expectedExpiry = block.timestamp + SUB_DURATION;

        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);

        assertEq(subscriptionManager.getSubscriptionExpiry(subscriber, creator), expectedExpiry);
    }

    function testGetSubscriptionExpiryForNonSubscriber() public {
        // Should return 0 for non-existent subscription
        assertEq(subscriptionManager.getSubscriptionExpiry(subscriber, creator), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function testSubscribeWithExactMinimumPrice() public {
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(MINIMUM_SUB_PRICE);

        vm.prank(subscriber);
        subscriptionManager.subscribe{value: MINIMUM_SUB_PRICE}(creator);

        assertTrue(subscriptionManager.isSubscribed(subscriber, creator));
    }

    function testMultipleRenewals() public {
        vm.prank(creator);
        subscriptionManager.setSubscriptionPrice(SUBSCRIPTION_PRICE);

        // Initial subscription
        vm.prank(subscriber);
        subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);
        uint256 firstExpiry = subscriptionManager.getSubscriptionExpiry(subscriber, creator);

        // Renew 3 times
        for (uint256 i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 5 days); // Fast forward 5 days each time
            vm.prank(subscriber);
            subscriptionManager.subscribe{value: SUBSCRIPTION_PRICE}(creator);
        }

        uint256 finalExpiry = subscriptionManager.getSubscriptionExpiry(subscriber, creator);
        
        // Should be 90 days from first subscription (3 x 30 days added)
        assertEq(finalExpiry, firstExpiry + (SUB_DURATION * 3));
    }
}