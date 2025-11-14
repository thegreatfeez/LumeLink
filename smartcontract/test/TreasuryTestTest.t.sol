// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../src/Treasury.sol";

contract TreasuryTest is Test {
    Treasury public treasury;

    address public owner;
    address public creator1;
    address public creator2;
    address public recipient;
    address public attacker;

    event FeeReceived(address indexed creator, uint256 amount, uint256 timestamp);
    event FeesWithdrawn(address indexed recipient, uint256 amount, bool isFullWithdrawal);

    function setUp() public {
        owner = makeAddr("owner");
        creator1 = makeAddr("creator1");
        creator2 = makeAddr("creator2");
        recipient = makeAddr("recipient");
        attacker = makeAddr("attacker");

        vm.prank(owner);
        treasury = new Treasury();

        vm.deal(creator1, 100 ether);
        vm.deal(creator2, 100 ether);
        vm.deal(attacker, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                           DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DeploymentSetsOwnerCorrectly() public {
        assertEq(treasury.owner(), owner);
    }

    function test_InitialBalanceIsZero() public {
        assertEq(treasury.getBalance(), 0);
    }

    function test_InitialTotalFeesCollectedIsZero() public {
        assertEq(treasury.totalFeesCollected(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                          RECEIVE FEE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ReceiveFee_UpdatesTotalFeesCollected() public {
        uint256 feeAmount = 1 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: feeAmount}(creator1);

        assertEq(treasury.totalFeesCollected(), feeAmount);
    }

    function test_ReceiveFee_UpdatesCreatorContribution() public {
        uint256 feeAmount = 2 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: feeAmount}(creator1);

        assertEq(treasury.creatorFeeContributions(creator1), feeAmount);
    }

    function test_ReceiveFee_UpdatesContractBalance() public {
        uint256 feeAmount = 3 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: feeAmount}(creator1);

        assertEq(treasury.getBalance(), feeAmount);
        assertEq(address(treasury).balance, feeAmount);
    }

    function test_ReceiveFee_EmitsEvent() public {
        uint256 feeAmount = 1 ether;
        uint256 expectedTimestamp = block.timestamp;

        vm.expectEmit(true, false, false, true);
        emit FeeReceived(creator1, feeAmount, expectedTimestamp);

        vm.prank(creator1);
        treasury.receiveFee{value: feeAmount}(creator1);
    }

    function test_ReceiveFee_MultipleCreators() public {
        uint256 amount1 = 2 ether;
        uint256 amount2 = 3 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: amount1}(creator1);

        vm.prank(creator2);
        treasury.receiveFee{value: amount2}(creator2);

        assertEq(treasury.totalFeesCollected(), amount1 + amount2);
        assertEq(treasury.creatorFeeContributions(creator1), amount1);
        assertEq(treasury.creatorFeeContributions(creator2), amount2);
    }

    function test_ReceiveFee_AccumulatesForSameCreator() public {
        uint256 firstPayment = 1 ether;
        uint256 secondPayment = 2 ether;

        vm.startPrank(creator1);
        treasury.receiveFee{value: firstPayment}(creator1);
        treasury.receiveFee{value: secondPayment}(creator1);
        vm.stopPrank();

        assertEq(treasury.creatorFeeContributions(creator1), firstPayment + secondPayment);
        assertEq(treasury.totalFeesCollected(), firstPayment + secondPayment);
    }

    function test_ReceiveFee_WithZeroAmount() public {
        vm.prank(creator1);
        treasury.receiveFee{value: 0}(creator1);

        assertEq(treasury.totalFeesCollected(), 0);
        assertEq(treasury.creatorFeeContributions(creator1), 0);
    }

    function testFuzz_ReceiveFee(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(creator1, amount);

        vm.prank(creator1);
        treasury.receiveFee{value: amount}(creator1);

        assertEq(treasury.totalFeesCollected(), amount);
        assertEq(treasury.creatorFeeContributions(creator1), amount);
        assertEq(treasury.getBalance(), amount);
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Withdraw_Success() public {
        uint256 feeAmount = 5 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: feeAmount}(creator1);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        treasury.withdraw();

        assertEq(treasury.getBalance(), 0);
        assertEq(owner.balance, ownerBalanceBefore + feeAmount);
    }

    function test_Withdraw_EmitsEvent() public {
        uint256 feeAmount = 2 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: feeAmount}(creator1);

        vm.expectEmit(true, false, false, true);
        emit FeesWithdrawn(owner, feeAmount, true);

        vm.prank(owner);
        treasury.withdraw();
    }

    function test_Withdraw_RevertsIfNotOwner() public {
        uint256 feeAmount = 1 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: feeAmount}(creator1);

        vm.prank(attacker);
        vm.expectRevert(Treasury.Treasury__OnlyOwnerCanWithdraw.selector);
        treasury.withdraw();
    }

    function test_Withdraw_RevertsIfNoBalance() public {
        vm.prank(owner);
        vm.expectRevert(Treasury.Treasury__NoFeesToWithdraw.selector);
        treasury.withdraw();
    }

    function test_Withdraw_PreventReentrancy() public {
        MaliciousReceiver malicious = new MaliciousReceiver(treasury);

        vm.prank(creator1);
        treasury.receiveFee{value: 2 ether}(creator1);

        vm.prank(owner);
        treasury.withdraw();
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAW TO TESTS
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawTo_Success() public {
        uint256 feeAmount = 10 ether;
        uint256 withdrawAmount = 4 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: feeAmount}(creator1);

        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(owner);
        treasury.withdrawTo(recipient, withdrawAmount);

        assertEq(treasury.getBalance(), feeAmount - withdrawAmount);
        assertEq(recipient.balance, recipientBalanceBefore + withdrawAmount);
    }

    function test_WithdrawTo_EmitsEvent() public {
        uint256 feeAmount = 5 ether;
        uint256 withdrawAmount = 2 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: feeAmount}(creator1);

        vm.expectEmit(true, false, false, true);
        emit FeesWithdrawn(recipient, withdrawAmount, false);

        vm.prank(owner);
        treasury.withdrawTo(recipient, withdrawAmount);
    }

    function test_WithdrawTo_RevertsIfNotOwner() public {
        uint256 feeAmount = 3 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: feeAmount}(creator1);

        vm.prank(attacker);
        vm.expectRevert(Treasury.Treasury__OnlyOwnerCanWithdraw.selector);
        treasury.withdrawTo(recipient, 1 ether);
    }

    function test_WithdrawTo_RevertsIfAmountIsZero() public {
        vm.prank(creator1);
        treasury.receiveFee{value: 5 ether}(creator1);

        vm.prank(owner);
        vm.expectRevert(Treasury.Treasury__InvalidAmount.selector);
        treasury.withdrawTo(recipient, 0);
    }

    function test_WithdrawTo_RevertsIfInsufficientBalance() public {
        uint256 feeAmount = 2 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: feeAmount}(creator1);

        vm.prank(owner);
        vm.expectRevert(Treasury.Treasury__InsufficientBalance.selector);
        treasury.withdrawTo(recipient, 3 ether);
    }

    function test_WithdrawTo_PartialWithdrawals() public {
        uint256 totalAmount = 10 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: totalAmount}(creator1);

        vm.startPrank(owner);

        treasury.withdrawTo(recipient, 3 ether);
        assertEq(treasury.getBalance(), 7 ether);

        treasury.withdrawTo(recipient, 2 ether);
        assertEq(treasury.getBalance(), 5 ether);

        treasury.withdrawTo(recipient, 5 ether);
        assertEq(treasury.getBalance(), 0);

        vm.stopPrank();
    }

    function test_WithdrawTo_CanWithdrawToOwner() public {
        uint256 feeAmount = 5 ether;
        uint256 withdrawAmount = 3 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: feeAmount}(creator1);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        treasury.withdrawTo(owner, withdrawAmount);

        assertEq(owner.balance, ownerBalanceBefore + withdrawAmount);
        assertEq(treasury.getBalance(), feeAmount - withdrawAmount);
    }

    function testFuzz_WithdrawTo(uint96 totalAmount, uint96 withdrawAmount) public {
        vm.assume(totalAmount > 0);
        vm.assume(withdrawAmount > 0);
        vm.assume(withdrawAmount <= totalAmount);

        vm.deal(creator1, totalAmount);

        vm.prank(creator1);
        treasury.receiveFee{value: totalAmount}(creator1);

        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(owner);
        treasury.withdrawTo(recipient, withdrawAmount);

        assertEq(treasury.getBalance(), totalAmount - withdrawAmount);
        assertEq(recipient.balance, recipientBalanceBefore + withdrawAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        GET BALANCE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetBalance_ReturnsCorrectBalance() public {
        assertEq(treasury.getBalance(), 0);

        vm.prank(creator1);
        treasury.receiveFee{value: 5 ether}(creator1);
        assertEq(treasury.getBalance(), 5 ether);

        vm.prank(creator2);
        treasury.receiveFee{value: 3 ether}(creator2);
        assertEq(treasury.getBalance(), 8 ether);

        vm.prank(owner);
        treasury.withdrawTo(recipient, 2 ether);
        assertEq(treasury.getBalance(), 6 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CompleteWorkflow() public {
        vm.prank(creator1);
        treasury.receiveFee{value: 5 ether}(creator1);

        vm.prank(creator2);
        treasury.receiveFee{value: 3 ether}(creator2);

        assertEq(treasury.totalFeesCollected(), 8 ether);
        assertEq(treasury.getBalance(), 8 ether);

        vm.prank(owner);
        treasury.withdrawTo(recipient, 2 ether);
        assertEq(treasury.getBalance(), 6 ether);

        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        treasury.withdraw();
        assertEq(treasury.getBalance(), 0);
        assertEq(owner.balance, ownerBalanceBefore + 6 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        SECURITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CannotWithdrawMoreThanBalance() public {
        vm.prank(creator1);
        treasury.receiveFee{value: 1 ether}(creator1);

        vm.prank(owner);
        vm.expectRevert(Treasury.Treasury__InsufficientBalance.selector);
        treasury.withdrawTo(recipient, 2 ether);
    }

    function test_NonOwnerCannotWithdraw() public {
        vm.prank(creator1);
        treasury.receiveFee{value: 5 ether}(creator1);

        address[] memory nonOwners = new address[](3);
        nonOwners[0] = creator1;
        nonOwners[1] = creator2;
        nonOwners[2] = attacker;

        for (uint256 i = 0; i < nonOwners.length; i++) {
            vm.prank(nonOwners[i]);
            vm.expectRevert(Treasury.Treasury__OnlyOwnerCanWithdraw.selector);
            treasury.withdraw();

            vm.prank(nonOwners[i]);
            vm.expectRevert(Treasury.Treasury__OnlyOwnerCanWithdraw.selector);
            treasury.withdrawTo(recipient, 1 ether);
        }
    }

    function test_TotalFeesTrackedCorrectly() public {
        uint256 amount1 = 2 ether;
        uint256 amount2 = 3 ether;
        uint256 amount3 = 1 ether;

        vm.prank(creator1);
        treasury.receiveFee{value: amount1}(creator1);

        vm.prank(creator2);
        treasury.receiveFee{value: amount2}(creator2);

        vm.prank(creator1);
        treasury.receiveFee{value: amount3}(creator1);

        assertEq(treasury.totalFeesCollected(), amount1 + amount2 + amount3);

        vm.prank(owner);
        treasury.withdraw();
        assertEq(treasury.totalFeesCollected(), amount1 + amount2 + amount3);
    }
}

/*//////////////////////////////////////////////////////////////
                    MALICIOUS CONTRACT
//////////////////////////////////////////////////////////////*/

contract MaliciousReceiver {
    Treasury public treasury;
    uint256 public attackCount;

    constructor(Treasury _treasury) {
        treasury = _treasury;
    }

    receive() external payable {
        if (attackCount < 2 && address(treasury).balance > 0) {
            attackCount++;

            treasury.withdraw();
        }
    }
}