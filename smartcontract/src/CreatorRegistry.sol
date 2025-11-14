// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CreatorRegistry {
    error CreatorRegistry__UserAlreadyRegistered();
    error CreatorRegistry__EmptyMetadataURI();
    error CreatorRegistry__UserNotRegistered();

    event CreatorRegistered(address indexed creator, string profileMetadataURI, uint256 timestamp);

    struct Creator {
        bool isRegistered;
        uint256 lastFeaturedTimeStamp;
        string profileMetadataURI;
    }

    mapping(address => Creator) public creators;
    address[] private s_creatorAddresses;

    function registerCreator(string memory _profileMetadataURI) public {
        if (creators[msg.sender].isRegistered) revert CreatorRegistry__UserAlreadyRegistered();

        if (bytes(_profileMetadataURI).length == 0) {
            revert CreatorRegistry__EmptyMetadataURI();
        }

        creators[msg.sender] =
            Creator({isRegistered: true, lastFeaturedTimeStamp: 0, profileMetadataURI: _profileMetadataURI});

        s_creatorAddresses.push(msg.sender);

        emit CreatorRegistered(msg.sender, _profileMetadataURI, block.timestamp);
    }

    function isCreator(address _addr) public view returns (bool) {
        return creators[_addr].isRegistered;
    }

    function getAllCreators() external view returns (address[] memory) {
        return s_creatorAddresses;
    }

    function getCreatorCount() external view returns (uint256) {
        return s_creatorAddresses.length;
    }

    function getLastFeaturedTimestamp(address _creator) external view returns (uint256) {
        return creators[_creator].lastFeaturedTimeStamp;
    }

    function updateLastFeatured(address _creator) external {
        if (!creators[_creator].isRegistered) revert CreatorRegistry__UserNotRegistered();
        creators[_creator].lastFeaturedTimeStamp = block.timestamp;
    }
}
