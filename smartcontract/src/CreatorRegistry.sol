// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CreatorRegistry {
    error CreatorRegistry__UserAlreadyRegistered();
    error CreatorRegistry__EmptyMetadataURI();

    event CreatorRegistered(address indexed creator, string profileMetadataURI, uint256 timestamp);

    struct Creator {
        bool isRegistered;
        uint256 lastFeaturedTimeStamp;
        string profileMetadataURI;
    }

    mapping(address => Creator) public creators;

    function registerCreator(string memory _profileMetadataURI) public {
        if (creators[msg.sender].isRegistered) revert CreatorRegistry__UserAlreadyRegistered();

        if (bytes(_profileMetadataURI).length == 0) {
            revert CreatorRegistry__EmptyMetadataURI();
        }

        creators[msg.sender] =
            Creator({isRegistered: true, lastFeaturedTimeStamp: 0, profileMetadataURI: _profileMetadataURI});

        emit CreatorRegistered(msg.sender, _profileMetadataURI, block.timestamp);
    }

    function isCreator(address _addr) public view returns (bool) {
        return creators[_addr].isRegistered;
    }
}
