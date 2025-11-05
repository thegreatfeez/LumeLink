// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CreatorRegistry} from "../src/CreatorRegistry.sol";

contract CreatorRegistryTest is Test {
    error CreatorRegistry__UserAlreadyRegistered();
    error CreatorRegistry__EmptyMetadataURI();

    event CreatorRegistered(address indexed creator, string profileMetadataURI, uint256 timestamp);

    CreatorRegistry public registry;
    address public PLAYER = makeAddr("player");
    string constant METADATA_URI = "https://api.spotchain.com/creator/1";

    function setUp() public {
        registry = new CreatorRegistry();
    }

    function testRegisterCreator() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(registry));
        emit CreatorRegistered(PLAYER, METADATA_URI, 0);

        registry.registerCreator(METADATA_URI);

        assertTrue(registry.isCreator(PLAYER));

        (bool registered, uint256 lastFeatured, string memory metaData) = registry.creators(PLAYER);
        assertTrue(registered);
        assertEq(lastFeatured, 0);
        assertEq(metaData, METADATA_URI);
    }

    function testCannotRegisterTwice() public {
        vm.prank(PLAYER);
        registry.registerCreator(METADATA_URI);
        assertTrue(registry.isCreator(PLAYER));

        //try to register again
        vm.prank(PLAYER);

        vm.expectRevert(CreatorRegistry__UserAlreadyRegistered.selector);
        registry.registerCreator(METADATA_URI);
    }

    function testCannotRegisterWithEmptyURI() public {
        vm.prank(PLAYER);

        vm.expectRevert(CreatorRegistry__EmptyMetadataURI.selector);
        registry.registerCreator("");
    }

    function testIsCreatorReturnsFalseForNonRegistered() public {
        // Check unregistered address
        assertFalse(registry.isCreator(PLAYER));

        // Register and check again
        vm.prank(PLAYER);
        registry.registerCreator(METADATA_URI);
        assertTrue(registry.isCreator(PLAYER));

        // Check different unregistered address
        address randomUser = makeAddr("random");
        assertFalse(registry.isCreator(randomUser));
    }
}
