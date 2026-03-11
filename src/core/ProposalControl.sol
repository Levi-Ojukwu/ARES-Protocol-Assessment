// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IProposalControl.sol";
import {Governance} from "../modules/Governance.sol";
import {MerkleDist} from "../modules/MerkleDist.sol";
import {SigAuth} from "../modules/SigAuth.sol";
import {SafeToken} from "../libraries/SafeToken.sol";
import {SafeTransfer} from "../libraries/SafeTransfer.sol";
import {AresToken} from "./AresToken.sol";

contract ProposalControl is IProposalControl, Governance, MerkleDist, SigAuth {
    using SafeToken    for address;
    using SafeTransfer for address;
    
    error WRONG_STATE();
    error ALREADY_EXECUTED();
    error UPGRADE_VALUE_FORBIDDEN();
    error ALREADY_CONFIRMED();
    error TIMELOCK_NOT_ELAPSED();
    error TIMELOCK_NOT_STARTED();
    error UPGRADE_DATA_REQUIRED();
    error NOT_PROPOSER();
    error WRONG_DEPOSIT();
    error NOT_GOVERNOR();
    error INVALID_GOVERNOR();
    error DUPLICATE_GOVERNOR();
    error REENTRANCY();

    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        address proposer;
        uint256 confirmations;
        ProposalState state;
        uint256 submittedAt;
        uint256 executeAfter;
        uint256 deposit;
        ActionType actionType;
    }

    address[] public governors;
    uint256 public threshold;
    uint256 public proposalCount;
    AresToken  public aresToken;

    mapping(address => bool) public isGovernor;
    mapping(uint256 => mapping(address => bool)) public confirmed;
    mapping(uint256 => Proposal) public proposals;

    uint256 private _status;

    uint256 public constant TIMELOCK_DURATION = 1 hours;

    modifier onlyGovernor() {
        if (!isGovernor[msg.sender]) revert NOT_GOVERNOR();
        _;
    }

    modifier nonReentrant() {
        if (_status == 2) revert REENTRANCY();
        _status = 2;
        _;
        _status = 1;
    }

    constructor(address[] memory _governors, uint256 _threshold) payable {
        require(_governors.length > 0, "no governors");

        require(_threshold > 0 && _threshold <= _governors.length, "invalid threshold");

        threshold = _threshold;

        for (uint256 i = 0; i < _governors.length; i++) {
            address g = _governors[i];
            if (g == address(0)) revert INVALID_GOVERNOR();
            if (isGovernor[g])   revert DUPLICATE_GOVERNOR();
            isGovernor[g] = true;
            governors.push(g);
        }

        aresToken = new AresToken(address(this));

        _setRewardToken(address(aresToken));

        _setMerkleAdmin(address(this));

    }

    function submitProposal(address _target, uint256 _value, bytes calldata _data, ActionType _actionType)
        public
        payable
        onlyGovernor
        returns (uint256 id)
    {

        if (msg.value != PROPOSAL_DEPOSIT) revert WRONG_DEPOSIT();

        if (_actionType == ActionType.Upgrade) {
            if (_value != 0) revert UPGRADE_VALUE_FORBIDDEN();

            if (_data.length < 4) revert UPGRADE_DATA_REQUIRED();
        }

        id = proposalCount++;

        proposals[id] = Proposal({
            target: _target,
            value: _value,
            data: _data,
            proposer: msg.sender,
            confirmations: 0,
            state: ProposalState.Pending,
            submittedAt: block.timestamp,
            executeAfter: 0,
            deposit: msg.value,
            actionType: _actionType
        });

        _lockDeposit(id, msg.sender);

        confirmed[id][msg.sender] = true;

        proposals[id].confirmations = 1;

        if (threshold == 1) {
            proposals[id].state = ProposalState.Queued;
            proposals[id].executeAfter = block.timestamp + TIMELOCK_DURATION;
            emit ProposalQueued(id, proposals[id].executeAfter);
        }

        emit ProposalSubmitted(id, msg.sender);
        
    }

    function confirmProposal(uint256 proposalId) public onlyGovernor {

        Proposal storage prop = proposals[proposalId];

        if (prop.state != ProposalState.Pending) revert WRONG_STATE();

        if (confirmed[proposalId][msg.sender]) revert ALREADY_CONFIRMED();

        confirmed[proposalId][msg.sender] = true;

        prop.confirmations++;

        if (prop.confirmations >= threshold) {
            prop.state = ProposalState.Queued;
            prop.executeAfter = block.timestamp + TIMELOCK_DURATION;
            emit ProposalQueued(proposalId, prop.executeAfter);
        }

        emit ProposalConfirmed(proposalId, msg.sender);
    }

    function executeProposal(uint256 proposalId) external virtual onlyGovernor nonReentrant {

        Proposal storage prop = proposals[proposalId];

        if (prop.state != ProposalState.Queued) revert WRONG_STATE();

        if (prop.executeAfter == 0) revert TIMELOCK_NOT_STARTED();

        if (block.timestamp < prop.executeAfter) revert TIMELOCK_NOT_ELAPSED();

        prop.state = ProposalState.Executed;

        _returnDeposit(proposalId);

        emit ProposalExecuted(proposalId);

        if (prop.actionType == ActionType.Transfer) {
            aresToken.mint(prop.target, prop.value);

        } else if (prop.actionType == ActionType.Call) {
            (bool success,) = prop.target.call{value: 0}(prop.data);
            require(success, "call execution failed");

        } else if (prop.actionType == ActionType.Upgrade) {
            aresToken.setMinter(prop.target);
        }
    }

    function cancelProposal(uint256 proposalId) public onlyGovernor {
        Proposal storage prop = proposals[proposalId];

        if (prop.state == ProposalState.Executed) revert ALREADY_EXECUTED();

        if (prop.state == ProposalState.Cancelled) revert WRONG_STATE();

        if (msg.sender != prop.proposer) revert NOT_PROPOSER();

        prop.state = ProposalState.Cancelled;

        _returnDeposit(proposalId);

        emit ProposalCancelled(proposalId);
    }

    function setMerkleRoot(bytes32 root) external override {

        if (msg.sender != merkleAdmin) revert NotMerkleAdmin();

        _setMerkleRoot(root);
    }

    function getState(uint256 proposalId) public view returns (ProposalState) {
        return proposals[proposalId].state;
    }

    receive() external payable virtual {}
}