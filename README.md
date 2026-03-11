# Protocol Specification

The ARES Protocol uses a simple step-by-step process to handle governance proposals. Each proposal moves through a few clear stages so actions taken by the protocol are transparent, reviewed, and executed safely.

## Proposal Creation
Everything starts with a proposal. A user submits an idea or request for the protocol to perform a specific action, such as transferring funds from the treasury or interacting with another contract. The proposal includes the necessary details like the target address, the function to call, and a short description explaining what it does. A small deposit is required when creating a proposal to discourage spam or low-effort submissions.

## Approval
After a proposal is created, it needs approval from the designated signers. These signers review the proposal and provide digital signatures if they agree with it. The protocol verifies these signatures and checks that enough approvals have been collected. Once the required number of signers approve, the proposal can move forward.

## Queueing
When a proposal has enough approvals, it gets placed in a queue inside the timelock contract. This step schedules the proposal for execution but introduces a waiting period. The delay gives the community time to review the proposal and ensures nothing happens instantly without oversight.

## Execution
Once the waiting period is over, the proposal becomes executable. At this stage, the protocol performs the action defined in the proposal—such as transferring tokens or calling another contract. After the action is completed successfully, the proposal is marked as executed so it cannot run again.

## Cancellation
In some situations, a proposal may need to be stopped before execution. For example, if an issue is discovered or the proposal is no longer needed. Authorized parties can cancel the proposal, which permanently stops it from moving forward in the process.