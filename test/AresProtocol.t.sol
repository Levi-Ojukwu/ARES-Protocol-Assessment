// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ProposalControl}  from "../src/core/ProposalControl.sol";
import {AresToken}        from "../src/core/AresToken.sol";
import {IProposalControl} from "../src/interfaces/IProposalControl.sol";

contract ReentrancyAttacker {
    ProposalControl public control;
    uint256 public targetId;
    uint256 public callCount;

    constructor(address payable t) { control = ProposalControl(t); }
    function setTarget(uint256 id) external { targetId = id; }

    receive() external payable {
        callCount++;
        if (callCount < 3) {
            try control.executeProposal(targetId) {} catch {}
        }
    }
}

contract ProposalControlTest is Test {

    ProposalControl control;
    AresToken       token;

    uint256 constant DEPOSIT = 0.01 ether;

    address alice;
    address cas;
    address levi;
    address mark;

    function setUp() public {
        alice = makeAddr("Alice");
        cas   = makeAddr("Cas");
        levi  = makeAddr("Levi");
        mark  = makeAddr("Mark");

        address[] memory govs = new address[](3);
        govs[0] = alice;
        govs[1] = cas;
        govs[2] = levi;

        control = new ProposalControl(govs, 2);
        token   = control.aresToken();

        vm.deal(address(control), 10 ether);
        vm.deal(alice, 5 ether);
        vm.deal(cas,   5 ether);
        vm.deal(levi,  5 ether);
        vm.deal(mark,  5 ether);
    }


    function testProposalLifecycle() public {
        address recipient = makeAddr("Recipient");

        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            recipient, 500e18, "", IProposalControl.ActionType.Transfer
        );

        assertEq(uint256(control.getState(id)), uint256(0));

        vm.prank(cas);
        control.confirmProposal(id);

        assertEq(uint256(control.getState(id)), uint256(1));

        vm.prank(alice);
        vm.expectRevert();
        control.executeProposal(id);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(alice);
        control.executeProposal(id);

        assertEq(uint256(control.getState(id)), uint256(2));
        assertEq(token.balanceOf(recipient), 500e18);
    }

    function testCancelProposal() public {
        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            cas, 0, "", IProposalControl.ActionType.Transfer
        );

        vm.prank(alice);
        control.cancelProposal(id);

        assertEq(uint256(control.getState(id)), uint256(3));
    }

    function testDepositReturnedOnExecute() public {
        uint256 aliceBefore = alice.balance;

        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            cas, 100e18, "", IProposalControl.ActionType.Transfer
        );

        vm.prank(cas);
        control.confirmProposal(id);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(alice);
        control.executeProposal(id);

        assertEq(alice.balance, aliceBefore);
    }

    function testDepositReturnedOnCancel() public {
        uint256 aliceBefore = alice.balance;

        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            cas, 0, "", IProposalControl.ActionType.Transfer
        );

        vm.prank(alice);
        control.cancelProposal(id);

        assertEq(alice.balance, aliceBefore);
    }

    function testCallProposal() public {
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", levi, 200e18);

        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            address(token), 0, data, IProposalControl.ActionType.Call
        );

        vm.prank(cas);
        control.confirmProposal(id);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(alice);
        control.executeProposal(id);

        assertEq(token.balanceOf(levi), 200e18);
    }

    function testUpgradeProposal() public {
        address newMinter = makeAddr("NewMinter");
        bytes memory data = abi.encodeWithSignature("setMinter(address)", newMinter);

        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            newMinter, 0, data, IProposalControl.ActionType.Upgrade
        );

        vm.prank(cas);
        control.confirmProposal(id);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(alice);
        control.executeProposal(id);

        assertEq(token.minter(), newMinter);
    }


    function testExploit_Reentrancy() public {
        ReentrancyAttacker attacker = new ReentrancyAttacker(payable(address(control)));

        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            address(attacker), 100e18, "", IProposalControl.ActionType.Transfer
        );

        vm.prank(cas);
        control.confirmProposal(id);

        attacker.setTarget(id);
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(alice);
        control.executeProposal(id);
        assertEq(token.balanceOf(address(attacker)), 100e18); // minted once, correctly
        assertEq(attacker.callCount(), 0, "no ETH sent, receive() never called");

        vm.prank(alice);
        vm.expectRevert();
        control.executeProposal(id);
    }

    function testExploit_PrematureExecution() public {
        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            cas, 0, "", IProposalControl.ActionType.Transfer
        );

        vm.prank(cas);
        control.confirmProposal(id);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(alice);
        vm.expectRevert();
        control.executeProposal(id);
    }

    function testExploit_ReplayExecution() public {
        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            cas, 100e18, "", IProposalControl.ActionType.Transfer
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

    function testExploit_NonGovernorSubmit() public {
        vm.prank(mark);
        vm.expectRevert();
        control.submitProposal{value: DEPOSIT}(
            alice, 0, "", IProposalControl.ActionType.Transfer
        );
    }

    function testExploit_ExecuteCancelledProposal() public {
        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            cas, 0, "", IProposalControl.ActionType.Transfer
        );

        vm.prank(alice);
        control.cancelProposal(id);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(alice);
        vm.expectRevert();
        control.executeProposal(id);
    }

    function testExploit_DoubleConfirm() public {
        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            cas, 0, "", IProposalControl.ActionType.Transfer
        );

        vm.prank(cas);
        control.confirmProposal(id);

        vm.prank(cas);
        vm.expectRevert();
        control.confirmProposal(id);
    }

    function testExploit_SubmitWithoutDeposit() public {
        vm.prank(alice);
        vm.expectRevert();
        control.submitProposal{value: 0}(
            cas, 0, "", IProposalControl.ActionType.Transfer
        );
    }

    function testExploit_InvalidMerkleProof() public {
        uint256 amount = 100e18;
        bytes32 root   = keccak256(bytes.concat(keccak256(abi.encode(alice, amount))));
        _setMerkleRootViaProposal(root);
        _mintTokensToControl(amount);

        bytes32[] memory fakeProof = new bytes32[](1);
        fakeProof[0] = keccak256("fake");

        vm.prank(mark);
        vm.expectRevert();
        control.claim(fakeProof, amount);
    }

    function testExploit_UnauthorizedCancel() public {
        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            cas, 0, "", IProposalControl.ActionType.Transfer
        );

        vm.prank(cas);
        vm.expectRevert();
        control.cancelProposal(id);
    }

    function testExploit_UpgradeWithValue() public {
        bytes memory data = abi.encodeWithSignature("setMinter(address)", alice);

        vm.prank(alice);
        vm.expectRevert();
        control.submitProposal{value: DEPOSIT}(
            alice, 1 ether, data, IProposalControl.ActionType.Upgrade
        );
    }

    function testExploit_UpgradeWithNoData() public {
        vm.prank(alice);
        vm.expectRevert();
        control.submitProposal{value: DEPOSIT}(
            alice, 0, "", IProposalControl.ActionType.Upgrade
        );
    }

    function _mintTokensToControl(uint256 amount) internal {
        vm.prank(address(control));
        token.mint(address(control), amount);
    }

    function _setMerkleRootViaProposal(bytes32 root) internal {
        bytes memory data = abi.encodeWithSignature("setMerkleRoot(bytes32)", root);

        vm.prank(alice);
        uint256 id = control.submitProposal{value: DEPOSIT}(
            address(control), 0, data, IProposalControl.ActionType.Call
        );

        vm.prank(cas);
        control.confirmProposal(id);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(alice);
        control.executeProposal(id);
    }

    receive() external payable {}
}