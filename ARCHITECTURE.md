# Ares Protocol System Architecture

Ares Protocol is a system designed where funds cannot move without going or passing through some kind of strict execution pipeline. where each treasury action starts as a proposal, then goes through several validation steps before it gets executed

The architecture separates responsibilities into different modules. And it helps prevents a single contract from having excessive authority and ensures that governance, execution, and reward distribution have their diffenet files and is seperated from one another.

A typical treasury action follows the flow below.

Governor
   ↓
ProposalControl
   (proposal lifecycle and confirmations)
   ↓
Timelock Queue
   (delayed execution scheduling)
   ↓
Execution Layer
   (transfer, call, or upgrade action)
   ↓
Target Contract / Token Distribution

Looking at this steps above, each step act as a safeguard that makes sure that protocols validation cannot be bypassed. All proposals must pass through every layer successfully before any action is executed.  

This design also reduces vulnerability that may compromise compromises the entire treasury.

--- 

## Module Separation

The ARES protocol consists of several contracts and libraries, each responsible for a distinct part of the system.

### ProposalControl
ProposalControl is the contract controling the governance execution and how proposals are created, approved, delayed, and executed in the protocol treasury system.

The contract integrates multiple governance, security, and modules, which allows the combination of proposal lifecycle management with deposit protection and rewards.

### Governance Module

The governance module provides protection that prevents the protocol against treasury draining attack or proposal spam. A deposit is required to submit a proposal that discourages malicious actors from over flooding the system with proposals that are not valid.

Deposits are returned automatically when a proposal is executed or cancelled.

### SigAuth Module

This is basically a signature authentication as the name implies. It implements cryptographic authorization based on EIP-712 signature standard.

Each signature contains the signers address, the action hash, and the signers nonce.And every successful signature verification consumes a nonce that makse sure a signature cannot be reused.

### MerkleDist Module

This is where the contributors rewards are distributed using the MerkleDist module.
Instead of having every recipient stored onchain, the system stores a merkle root representing the set of distribution. The contract tracks each claim per distribution round to avoid double claiming. SO each eligible contributor can submit a merkle proof to verify their entitlement and claim their rewards. 

### AresToken

AresToken is the reward token used for paying out contributors. 

The token is minted by the governance system and distributed either through executing proposals or by the merkle rewards mechanism.
And only an authorized minter can create a new token or new tokens. And this ensures that token issuance remains under the governance control.

---


## Security Boundaries 

The system restricts actors that can perform actions and actors that are aunthorized to perform actions.

*** Who can submit proposals? 
Only registered governors

*** Who can confirm proposals?
Only governors

*** Who can execute proposals?
Only governors, after the timelock delay.

*** Who can cancel proposals?
Only the original proposer.

*** Who can update the Merkle root?
Only the authorized Merkle admin that was set to the governance contract.

Who can mint ARES tokens?
Only the designated minter.

These ensures that the governance authority is distributed among multiple actors, and single participants or actors cannot move treasury assets.

---

## Trust Assumption

This protocol has many practical assumptions 

- The governance are assumed to protect the private keys. If the major of the governance gets compromised, an attacker can have an approval of malicious proposals.

- The block timestamps are assumes to be accurate. We have a constant timeblock and is measured in hours, little timestamp deviations cannot meaningfully impact security. 

So generally, the architecture priortize modularity and security controls to minimize risks.