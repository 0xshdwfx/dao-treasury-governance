# DAO Treasury and Governance Specification

## 1. Purpose

This project is a decentralised governance system for controlling a treasury that can hold ETH and ERC-20 tokens.

Holders of the Shadow (SHDW) governance token can create and vote on proposals. A successful proposal can authorise an action involving the Treasury, such as transferring assets.

Successful proposals are not executed immediately. They pass through a Timelock, which creates a delay between governance approval and Treasury execution.

The purpose of this project is to demonstrate how token-based voting, proposal execution delays, and Treasury access control can work together.

## 2. System Components

The system consists of four smart-contract components:

### 2.1 Shadow Governance Token

The Shadow (SHDW) token represents voting power in the DAO. Token holders can delegate their voting power and use it to participate in governance.

### 2.2 Governor

The Governor manages proposals and voting. It determines whether a proposal has met the proposal threshold, voting rules, quorum requirement, and passing conditions.

### 2.3 Timelock

The Timelock delays successful proposals before they can be executed. This gives participants time to inspect an approved proposal before it affects the Treasury.

### 2.4 Treasury

The Treasury holds ETH and ERC-20 tokens. It only allows transfers that are caused by the Timelock.

## 3. Confirmed Parameters

| Parameter                 | Value                         |
| ------------------------- | ----------------------------- |
| Governance token          | Shadow                        |
| Token symbol              | SHDW                          |
| Total supply              | 1,000,000 tokens              |
| Decimals                  | 18                            |
| Initial supply allocation | Deployer                      |
| Proposal threshold        | 10,000 delegated voting power |
| Voting delay              | 1 minute                      |
| Voting period             | 5 minutes                     |
| Quorum                    | 40,000 voting units           |
| Timelock delay            | 2 minutes                     |
| Execution window          | 24 hours after becoming ready |

The initial allocation of the complete SHDW supply to the deployer is a deliberate portfolio simplification. It creates a centralisation risk because the deployer initially controls all token-based voting power.

### Timing Assumption

The voting delay and voting period are intentionally short so the complete governance lifecycle can be tested efficiently. These durations would be unsuitable for a production DAO, where participants would require substantially more time to review proposals and vote.

## 4. Voting Rules

Voting power is based on delegated SHDW voting units.

A proposal may be created only when the proposer has at least 10,000 delegated voting power.

Each voter may vote once on a proposal using one of three choices:

- For
- Against
- Abstain

Abstain votes count towards quorum but do not count as either For or Against votes.

A proposal succeeds only when both conditions are true:

1. Total voting participation reaches at least 40,000 voting units.
2. For votes are strictly greater than Against votes.

A proposal with equal For and Against votes fails, even if quorum has been reached.

A proposal that does not meet both conditions is defeated and must not be queued for execution.

## 5. Proposal Lifecycle

A proposal follows this lifecycle:

    Pending → Active → Succeeded or Defeated → Queued → Ready → Executed or Expired

### Pending

The proposal has been created, but voting has not started. The proposal remains pending for the one-minute voting delay.

### Active

The voting delay has ended and voters may cast their votes. Voting remains active for five minutes.

### Succeeded

Voting has ended, quorum has been reached, and For votes strictly exceed Against votes.

### Defeated

Voting has ended and either quorum was not reached or For votes did not strictly exceed Against votes.

### Queued

A successful proposal has been submitted to the Timelock. Anyone may queue a successful proposal.

### Ready

The two-minute Timelock delay has elapsed. The proposal can now be executed.

### Executed

The proposal actions have been executed successfully. Anyone may execute a ready proposal.

### Expired

The proposal became ready but was not executed within the 24-hour execution window.

## 6. Authority Model

The governance system follows this authority chain:

    SHDW holders → Governor → Timelock → Treasury

SHDW holders create and vote on proposals.

The Governor manages proposals, counts votes, and determines whether a proposal succeeds.

The Timelock receives successful proposals and delays their execution.

The Treasury holds ETH and ERC-20 tokens. Only the Timelock may cause Treasury transfers.

The deployer receives the initial SHDW supply. This is a deliberate portfolio simplification and creates a centralisation risk because the deployer initially controls all voting power.

No account should be able to bypass the Governor and Timelock to transfer assets from the Treasury.

## 7. Treasury Rules

The Treasury can hold:

- ETH
- ERC-20 tokens

The Treasury may receive assets from external accounts.

Only the Timelock may cause assets to leave the Treasury.

Direct transfer attempts from any other account must fail.

A Treasury transfer may occur only after:

1. A proposal has succeeded.
2. The proposal has been queued.
3. The Timelock delay has elapsed.
4. The proposal has not expired.
5. The proposal has not already been executed.

If a proposal contains multiple actions, all actions must execute as one operation. If any action fails, the complete operation must fail.

## 8. Trust Assumptions and Risks

This project assumes that:

- the governance token correctly records delegated voting power;
- voting power is read from the correct historical checkpoint;
- the Governor correctly enforces the proposal threshold, voting period, quorum, and passing conditions;
- the Timelock correctly enforces the execution delay and execution window;
- proposal actions and encoded calldata are reviewed before voting;
- deployment roles and permissions are configured correctly;
- the Treasury correctly restricts transfers to the Timelock;
- the ERC-20 tokens held by the Treasury behave within the assumptions tested by the project.

The complete initial SHDW supply is allocated to the deployer. This is a deliberate portfolio simplification and creates a centralisation risk. The deployer initially controls all token-based voting power and may therefore have significant influence over proposals.

This design is not presented as a production-ready decentralised governance distribution model. A production system would require a more carefully designed token distribution, stronger operational controls, and additional review.

## 9. Out of Scope

The following features are outside the scope of this portfolio implementation:

- production-scale token distribution;
- token sales or liquidity incentives;
- off-chain voting;
- delegation marketplaces;
- upgradeable contracts;
- cross-chain governance;
- emergency shutdown mechanisms;
- dispute resolution;
- formal verification;
- professional external audits.

These exclusions keep the implementation focused on the core governance, Timelock, and Treasury lifecycle.

## 10. Selected Architecture

The project will use the following contract architecture:

    ERC20Votes → Governor → TimelockController → Treasury

### ERC20Votes

The Shadow token will use OpenZeppelin's voting-token functionality to support delegated and checkpointed voting power.

### Governor

The Governor will manage proposal creation, voting, quorum, and proposal outcomes.

### TimelockController

The TimelockController will delay successful proposals before execution.

### Treasury

The Treasury will hold ETH and ERC-20 tokens. It will restrict outgoing transfers so that only the TimelockController can cause them.

OpenZeppelin's standard governance components will be used where they satisfy the confirmed specification. Any custom behaviour required by this project must be documented and tested explicitly.
