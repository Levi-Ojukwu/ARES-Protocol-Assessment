# ARES Protocol Security Analysis

## Major Attack Surfaces

### 1. Reentrancy

This is one of the most common vulnerabilities in smart contracts systems. Attackers could attempt to a particullar function or functions like `executeProposal` to trigger multiple operations.

Mitigation: This can me mitigated using two independent defenses.

- nonReentrant modifier that makes sure that a proposal execution cannot reenter the function before or while it is still running.

- prop.state which is the proposal state is set to Executed before any
  external call or action. This prevents the same reentrant attempt and it fails the state check immediately.

Together, these can protect the possibility of reentrancy.

---

### 2. Signature Replay

This attack occurs when a valid su=ignature is is reused to authorize multiple actions. A governor approval signature could be reused on the same chain or replayed on a fork.

Mitigation: This can me mitigated using four independent protections.
- One nonce per signer, where each use of `_verifyAndConsume()` increments nonces[signer].
  So same signature fails on second attempt.

- Domain separator: bakes block.chainid and address(this) into every digest.
  A signature from mainnet cannot work on a fork or different contract.

- We used EIP-712 typed data that allows wallets show users exactly what they are signing.

- Malleability check s-value restricted to lower half of curve order.

The `SigAuth` module prevents this through nonce management. Where each signer has an associated nonce that increments when a signature is consumed.

---

### 3. Double Claim

Surface: A contributor calls claim() more than once to drain extra rewards.

Mitigation: Claims tracked in _claimed[round][claimant]. Marked true before
transfer (CEI). Second call reverts with AlreadyClaimed before any transfer.
Round dimension ensures new root does not re-open previous round claims.

Residual risk: None for double claims within the contract.

---

### 4. Unauthorized Execution

Surface: A non-governor submits or executes proposals.

Mitigation: onlyGovernor modifier on submitProposal, confirmProposal,
executeProposal, and cancelProposal. Governor list set once at deployment.
No addGovernor function exists, removing that attack vector.

Residual risk: Governor set is immutable. Rotation requires an Upgrade proposal
deploying a new contract.

---

### 5. Timelock Bypass

Surface: Executing a proposal before the 1-hour delay.

Mitigation: executeProposal checks both executeAfter != 0 and
block.timestamp >= prop.executeAfter. nonReentrant prevents bypass via
reentrancy during the external call.

Residual risk: Miner timestamp manipulation possible within ~15 seconds.
The 1-hour window is 240x larger — practically useless attack.

---

### 6. Governance Griefing

Surface: Malicious governor spams proposals or targets critical functions.

Mitigation:
- Proposal deposit (0.01 ETH): spam has a real cost per proposal.

- Daily spend cap (10%): even a fully executed proposal cannot drain more
  than 10% of the treasury in one day.
  
- Cancel restriction: only the original proposer can cancel. Other governors
  cannot grief legitimate proposals by cancelling them.

Residual risk: Two-of-three malicious governors can execute anything.
The honest majority assumption must hold.

---

### 7. Flash Loan Governance Manipulation

Surface: Borrowing a large token balance in one transaction to influence
governance decisions.

Mitigation: ARES governance is based on pre-registered governor addresses,
not token balances. Flash loans cannot register a new governor. Token
holdings have zero effect on voting power.


---

### 8. Merkle Root Manipulation

Surface: Attacker sets a fraudulent root to claim excess tokens.

Mitigation: setMerkleRoot checks msg.sender == merkleAdmin. merkleAdmin is
address(this). The only way msg.sender equals address(this) is through an
executed Call proposal. Direct external calls always fail.

Residual risk: Off-chain tree construction compromise is a social/operational
risk, not a contract risk.
