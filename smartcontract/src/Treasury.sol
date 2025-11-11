// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract Treasury is ReentrancyGuard {
    error Treasury__OnlyOwnerCanWithdraw();
    error Treasury__WithdrawalFailed();
    error Treasury__NoFeesToWithdraw();
    error Treasury__InsufficientBalance();
    error Treasury__InvalidAmount();

    event FeeReceived(address indexed creator, uint256 amount, uint256 timestamp);
    event FeesWithdrawn(address indexed recipient, uint256 amount, bool isFullWithdrawal);

    address public immutable owner;
    uint256 public totalFeesCollected;
    mapping(address creator => uint256 feesGenerated) public creatorFeeContributions;

    constructor() {
        owner = msg.sender;
    }

    function receiveFee(address _creator) external payable {
        totalFeesCollected += msg.value;
        creatorFeeContributions[_creator] += msg.value;
        emit FeeReceived(_creator, msg.value, block.timestamp);
    }

    function withdraw() external nonReentrant {
        if(msg.sender != owner) revert Treasury__OnlyOwnerCanWithdraw();
        
        uint256 balance = address(this).balance;
        if(balance == 0) revert Treasury__NoFeesToWithdraw();

        (bool success, ) = payable(owner).call{value: balance}("");
        if(!success) revert Treasury__WithdrawalFailed();
        
        emit FeesWithdrawn(owner, balance, true);
    }

    function withdrawTo(address _recipient, uint256 _amount) external nonReentrant {
        if(msg.sender != owner) revert Treasury__OnlyOwnerCanWithdraw();
        if(_amount == 0) revert Treasury__InvalidAmount();
        if(_amount > address(this).balance) revert Treasury__InsufficientBalance();

        (bool success, ) = payable(_recipient).call{value: _amount}("");
        if(!success) revert Treasury__WithdrawalFailed();
        
        emit FeesWithdrawn(_recipient, _amount, false);
    }

    function getBalance() public view returns(uint256) {
        return address(this).balance;
    }
}