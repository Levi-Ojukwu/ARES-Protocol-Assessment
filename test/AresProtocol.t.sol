// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ProposalControl} from "../src/core/ProposalControl.sol";
import {IProposalControl} from "../src/interfaces/IProposalControl.sol";

contract ReentrancyAttacker {

    ProposalControl public control;

    uint256 public targetId;

    uint256 public callCount;

    constructor(address payable t) {
        control = ProposalControl(t);
    }

    function setTarget(uint256 id) external {
        targetId = id;
    }

    receive() external payable {
        callCount++;
        
        if (callCount < 3) {
            try control.executeProposal(targetId) {} catch {}
        }
    }
}

contract GriefingReceiver {
    receive() external payable {
        revert("no ETH");
    }
}

contract ProposalControlTest is Test {
    ProposalControl control;

    uint256 constant DEPOSIT = 0.01 ether;

    address alice = makeAddr("Alice");
    address cas   = makeAddr("Cas");
    address levi  = makeAddr("Levi");
    address mark  = makeAddr("Mark");

    function setUp() public {
        address[] memory govs = new address[](3);

        govs[0] = alice;
        govs[1] = cas;
        govs[2] = levi;

        control = new ProposalControl(govs, 2);

        vm.deal(address(control), 10 ether);

        vm.deal(alice, 5 ether);

        vm.deal(cas,   5 ether);

        vm.deal(levi,  5 ether);

        vm.deal(mark,  5 ether);
    }

    function testProposal() public {
        address recipient = makeAddr("Recipient");

        vm.prank(alice);

        uint256 id = control.submitProposal{value: DEPOSIT}(
            recipient,
            1 ether,
            "",
            IProposalControl.ActionType.Transfer
        );

        assertEq(uint256(control.getState(id)), uint256(0));

        vm.prank(cas);

        control.confirmProposal(id);

        assertEq(uint256(control.getState(id)), uint256(1));

        vm.prank(alice);

        vm.expectRevert();

        control.executeProposal(id);

        vm.warp(block.timestamp + 1 hours + 1);

        uint256 before = recipient.balance;

        vm.prank(alice);

        control.executeProposal(id);

        assertEq(uint256(control.getState(id)), uint256(2));

        assertEq(recipient.balance, before + 1 ether);
    }

    function testCancelProposal() public {
        vm.prank(alice);

        uint256 id = control.submitProposal{value: DEPOSIT}(
            cas,
            0,
            "",
            IProposalControl.ActionType.Transfer
        );

        vm.prank(alice);

        control.cancelProposal(id);

        assertEq(uint256(control.getState(id)), uint256(3));
    }


    function testReentrancyExploit() public {
        ReentrancyAttacker attacker =
            new ReentrancyAttacker(payable(address(control)));

        vm.prank(alice);

        uint256 id = control.submitProposal{value: DEPOSIT}(
            address(attacker),
            0.1 ether,
            "",
            IProposalControl.ActionType.Transfer
        );

        vm.prank(cas);

        control.confirmProposal(id);

        attacker.setTarget(id);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(alice);

        control.executeProposal(id);

        assertEq(attacker.callCount(), 1, "reentrant call must be blocked");
    }

    function testDepositReturnedOnExecute() public {

        uint256 aliceBefore = alice.balance;

        vm.prank(alice);

        uint256 id = control.submitProposal{value: DEPOSIT}(
            address(control),
            0,
            "",
            IProposalControl.ActionType.Call
        );

        vm.prank(cas);

        control.confirmProposal(id);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(alice);

        control.executeProposal(id);

        assertEq(alice.balance, aliceBefore);
    }

    function testExecuteCancelledProposalExploit() public {

        vm.prank(alice);

        uint256 id = control.submitProposal{value: DEPOSIT}(
            cas,
            0,
            "",
            IProposalControl.ActionType.Transfer
        );

        vm.prank(alice);

        control.cancelProposal(id);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(alice);

        vm.expectRevert();

        control.executeProposal(id);
    }

    function testPrematureExecutionExploit() public {
        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            cas,
            0,
            "",
            IProposalControl.ActionType.Transfer
        );

        vm.prank(cas);

        control.confirmProposal(id);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(alice);

        vm.expectRevert();

        control.executeProposal(id);
    }

    function testReplayExecutionExploit() public {
        vm.prank(alice);

        uint256 id = control.submitProposal{value: DEPOSIT}(
            address(control),
            0,
            "",
            IProposalControl.ActionType.Call
        );

        vm.prank(cas);

        control.confirmProposal(id);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(alice);

        control.executeProposal(id);

        vm.prank(alice);

        vm.expectRevert();

        control.executeProposal(id);
    }

    function testNonGovernorSubmitExploit() public {

        vm.prank(mark);

        vm.expectRevert();

        control.submitProposal{value: DEPOSIT}(
            alice,
            0,
            "",
            IProposalControl.ActionType.Transfer
        );
    }

    function testDoubleConfirmExploit() public {
        vm.prank(alice);

        uint256 id = control.submitProposal{value: DEPOSIT}(
            cas,
            0,
            "",
            IProposalControl.ActionType.Transfer
        );

        vm.prank(cas);

        control.confirmProposal(id);

        vm.prank(cas);
        
        vm.expectRevert();

        control.confirmProposal(id);
    }

    function testSubmitWithoutDepositExploit() public {

        vm.prank(alice);

        vm.expectRevert();

        control.submitProposal{value: 0}(
            cas,
            0,
            "",
            IProposalControl.ActionType.Transfer
        );
    }

    receive() external payable {}
}