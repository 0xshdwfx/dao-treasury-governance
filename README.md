# DAO Treasury and Governance

An on-chain governance system built with Solidity, Foundry, and OpenZeppelin Contracts. Shadow token holders can propose and vote on actions that execute through a Timelock to manage ETH and ERC-20 assets held by a Treasury.

The project demonstrates delegated voting, historical voting checkpoints, delayed execution, Treasury access control, and atomic proposal execution.

> **Status:** Smart contracts implemented with unit, integration, fuzz, and stateful invariant tests. Deployment and the governance frontend remain subsequent development stages.
>
> **Security:** Portfolio implementation. Not externally audited or intended for use with real funds.

---

## Overview

The system separates governance decisions from asset custody:

- **ShadowToken** provides delegated, checkpointed voting power.
- **ShadowGovernor** manages proposals, voting, quorum, and proposal outcomes.
- **TimelockController** delays approved actions before execution.
- **Treasury** holds assets and restricts withdrawals to its configured owner.

The intended authority chain is:

```text
SHDW holders
    ↓ propose and vote
ShadowGovernor
    ↓ schedules approved actions
TimelockController
    ↓ executes after the required delay
Treasury
    ↓ transfers approved assets
Recipient
```

The Treasury does not independently inspect proposals or count votes. It authorises calls from its owner, which must be configured as the real Timelock during deployment.

The full design and trust assumptions are documented in [DAO_SPECIFICATION.md](docs/DAO_SPECIFICATION.md).

---

## Features

- **Delegated Voting:** SHDW holders delegate to themselves or another address to activate voting power.
- **Historical Voting Checkpoints:** Proposal votes use voting power at the proposal snapshot.
- **Proposal Threshold:** Proposal creation requires sufficient delegated voting power.
- **Three Voting Choices:** For, Against, and Abstain.
- **Fixed Quorum:** For and Abstain votes contribute towards an absolute quorum.
- **Delayed Execution:** Successful proposals must be queued before execution.
- **Permissionless Execution Trigger:** Anyone can trigger ready operations when the Timelock executor role is open.
- **ETH and ERC-20 Custody:** The Treasury accepts ETH and incoming token transfers.
- **Restricted Withdrawals:** Only the configured Treasury owner can transfer assets out.
- **Fixed Treasury Ownership:** Ownership transfer and renunciation are disabled.
- **Safe ERC-20 Transfers:** Token withdrawals use OpenZeppelin’s `SafeERC20`.
- **Atomic Batches:** A failed action reverts the entire proposal execution, including earlier payments.
- **Custom Errors:** Explicit errors identify invalid inputs and failed operations.

---

## Governance Parameters

| Parameter                                              | Value                         |
| ------------------------------------------------------ | ----------------------------- |
| Token name                                             | Shadow                        |
| Token symbol                                           | SHDW                          |
| Initial supply                                         | 1,000,000 SHDW                |
| Token decimals                                         | 18                            |
| Initial supply recipient                               | Token deployer                |
| Voting clock                                           | Block timestamp               |
| Initial proposal threshold                             | 10,000 delegated voting units |
| Initial voting delay                                   | 1 minute                      |
| Initial voting period                                  | 5 minutes                     |
| Fixed quorum                                           | 40,000 voting units           |
| Initial Timelock delay used in the integration fixture | 2 minutes                     |

The voting delay, voting period, and proposal threshold can be changed through governance. Their constants describe initial settings, not permanently enforced values.

Quorum remains fixed at 40,000 voting units.

**These short timings are intended for development and demonstration.** A production DAO would require substantially more time for proposal review, voting, and operational response.

### Voting Rules

A proposal succeeds only when both conditions hold:

- For votes plus Abstain votes reach quorum.
- For votes are strictly greater than Against votes.

Against votes do not contribute towards quorum. Abstain votes contribute towards quorum but do not count as support for or opposition to the proposal.

A tie between For and Against votes defeats the proposal.

Holding SHDW alone does not activate voting power. Tokens must be delegated, including when the holder intends to vote directly.

---

## Proposal Lifecycle

```text
Pending → Active → Succeeded → Queued → Executed
                  ↘ Defeated
```

- **Pending:** The proposal exists, but its voting delay has not elapsed.
- **Active:** Eligible voters can vote using their snapshot voting power.
- **Succeeded:** Voting has ended and the proposal satisfies quorum and majority requirements.
- **Defeated:** Voting has ended without satisfying both requirements.
- **Queued:** The successful proposal has been scheduled in the Timelock.
- **Executed:** All proposal actions have completed successfully.

Once the execution delay expires, the Timelock operation becomes ready. **Ready is a Timelock operation status, not a separate Governor proposal state**; the Governor proposal remains `Queued` until execution.

Queued operations do not automatically expire.

### Example: Treasury Payment

A proposal can encode an instruction such as:

```text
Target: Treasury
Action: transferEth(recipient, amount)
Proposal ETH value: 0
```

The proposal value is zero because the Treasury spends ETH it already holds.

After approval and queueing, an ordinary user can trigger:

```text
Ordinary user → Governor → Timelock → Treasury → Recipient
```

The user triggers execution; the Treasury supplies the payment.

Proposal targets, values, calldata, and the description hash must identify the approved proposal. Changing them does not modify the existing approval.

---

## Smart Contracts

### ShadowToken.sol

An ERC-20 governance token using OpenZeppelin’s `ERC20Permit` and `ERC20Votes`.

- Mints the initial supply to the deployer.
- Supports delegation and historical voting checkpoints.
- Uses a timestamp-based voting clock.
- Provides permit-based approvals through the inherited implementation.

### ShadowGovernor.sol

Combines OpenZeppelin’s governance extensions:

- `GovernorSettings`
- `GovernorCountingSimple`
- `GovernorVotes`
- `GovernorTimelockControl`

The contract configures the initial governance settings and implements a fixed absolute quorum.

### TimelockController

Uses OpenZeppelin’s `TimelockController` directly.

The integration fixture:

- Grants the Governor `PROPOSER_ROLE`.
- Opens execution by granting `EXECUTOR_ROLE` to `address(0)`.
- Retains the Timelock’s own admin role.
- Renounces the test contract’s temporary admin role after configuration.

This setup is verified in tests. A real deployment must independently establish and verify its roles; test setup does not configure a live deployment.

### Treasury.sol

Holds ETH and ERC-20 assets.

- Accepts ETH through a payable `receive()` function.
- Receives ERC-20 tokens through direct token transfers.
- Restricts outgoing transfers to its configured owner.
- Rejects invalid recipients, zero withdrawal amounts, and insufficient balances.
- Checks ETH transfer success.
- Uses `SafeERC20` for token withdrawals.
- Emits withdrawal events.
- Disables ownership transfer and renunciation.

For fee-on-transfer tokens, the recipient may receive less than the requested amount. The ERC-20 withdrawal event records the requested amount, not a guaranteed net receipt.

---

## Technology Stack

- **Solidity:** 0.8.26
- **Foundry:** Compilation, testing, coverage, and scripting
- **OpenZeppelin Contracts:** v5.7.0 in the current dependency checkout
- **forge-std:** Test assertions, cheatcodes, fuzz bounds, and invariant targeting

Dependencies should be restored from the repository’s pinned revisions rather than updated automatically.

---

## Repository Structure

```text
.
├── contracts/
│   ├── src/
│   │   ├── ShadowToken.sol
│   │   ├── ShadowGovernor.sol
│   │   └── Treasury.sol
│   ├── script/
│   ├── test/
│   │   ├── unit/
│   │   │   ├── ShadowTokenTest.t.sol
│   │   │   ├── ShadowGovernorTest.t.sol
│   │   │   └── TreasuryTest.t.sol
│   │   ├── integration/
│   │   │   └── DAOGovernanceIntegrationTest.t.sol
│   │   ├── fuzz/
│   │   │   └── TreasuryFuzzTest.t.sol
│   │   ├── invariant/
│   │   │   ├── TreasuryInvariantTest.t.sol
│   │   │   └── handlers/
│   │   │       └── TreasuryHandler.sol
│   │   └── mocks/
│   ├── lib/
│   └── foundry.toml
├── docs/
│   └── DAO_SPECIFICATION.md
├── frontend/
└── README.md
```

The frontend directory is reserved for the application layer. This README currently documents the implemented smart-contract system and local testing workflow.

---

## Local Development

### Prerequisites

- Git
- Foundry, including `forge`

An RPC endpoint, wallet, and funded account are not required to run the local test suite.

### Restore Dependencies and Build

From the repository root:

```bash
git submodule update --init --recursive
cd contracts
forge build
```

### Run All Tests

From `contracts/`:

```bash
forge test
```

### Run Individual Suites

```bash
forge test --match-contract ShadowTokenTest
forge test --match-contract ShadowGovernorTest
forge test --match-contract TreasuryTest
forge test --match-contract DAOGovernanceIntegrationTest
forge test --match-contract TreasuryFuzzTest
forge test --match-contract TreasuryInvariantTest -vv
```

### Coverage

```bash
forge coverage --report summary
```

### Check Formatting

```bash
forge fmt --check
```

Do not commit private keys, seed phrases, RPC credentials, or local environment files.

---

## Testing Strategy

The latest validated suite contains **95 passing tests**, with no failures or skips.

| Suite               | Tests | Main purpose                                                                     |
| ------------------- | ----- | -------------------------------------------------------------------------------- |
| ShadowToken unit    | 9     | Token configuration, balances, delegation, and historical voting power           |
| ShadowGovernor unit | 50    | Proposal validation, voting, lifecycle, execution, and governance access control |
| Treasury unit       | 25    | Deposits, withdrawal validation, permissions, and token compatibility cases      |
| DAO integration     | 5     | Real Governor-to-Timelock-to-Treasury interactions                               |
| Treasury fuzz       | 4     | Withdrawal properties across generated balances and amounts                      |
| Treasury invariant  | 2     | Accounting rules across generated action sequences                               |

Fuzz and invariant entries count test functions, not individual generated cases or handler calls.

### Integration Tests

The integration suite verifies:

- Treasury ownership and final Timelock roles.
- Approved ETH payments through the real governance chain.
- Approved SHDW payments through the real governance chain.
- Failed withdrawals preserve balances and leave the proposal queued.
- A failed later batch action rolls back an earlier Treasury payment.

Successful integration executions are triggered by an ordinary user. The Timelock is not impersonated to perform those Treasury withdrawals.

### Fuzz Tests

The fuzz suite generates valid and excessive withdrawal amounts for ETH and SHDW.

It checks:

- Exact Treasury and recipient balance changes for valid withdrawals.
- Expected errors and unchanged balances for excessive withdrawals.

### Stateful Invariant Tests

Foundry generates sequences using four handler actions:

- `depositEth`
- `withdrawEth`
- `depositToken`
- `withdrawToken`

The invariants check:

```text
Treasury ETH balance
    == tracked ETH deposits − tracked ETH withdrawals

Treasury SHDW balance
    == tracked SHDW deposits − tracked SHDW withdrawals
```

These properties assume an initially empty Treasury and asset movements controlled by the handler.

The handler bounds amounts to affordable values and skips actions when the relevant balance is zero. Withdrawal actions impersonate the configured owner to isolate Treasury accounting from governance.

ETH deposits fund the handler using a cheatcode before making a real payment. SHDW deposits use tokens allocated to the handler during setup.

### Why SHDW Withdrawals Return to the Handler

Withdrawn SHDW returns to the handler so subsequent actions can deposit it again.

```text
Handler → Treasury → Handler → Treasury
```

Without recycling, tokens could accumulate at an external recipient until both the handler and Treasury became empty, reducing later token actions to early returns.

This is a test-harness choice, not a production recipient restriction. The integration suite separately verifies governance-approved payments to an external recipient.

Counters track cumulative transfers, so the same tokens can contribute to deposits and withdrawals multiple times.

### Campaign Configuration

```toml
[profile.default.fuzz]
runs = 256

[profile.default.invariant]
runs = 256
depth = 500
fail_on_revert = true
```

Unexpected handler reverts fail invariant testing. The latest validated campaign reported 128,000 handler calls per invariant with zero reverts.

Handler call statistics include early-return calls; they do not imply every call moved assets.

No fixed random seed is configured.

---

## Coverage Results

The latest coverage report measured:

| Production contract | Lines | Statements | Branches | Functions |
| ------------------- | ----- | ---------- | -------- | --------- |
| ShadowGovernor.sol  | 18/18 | 15/15      | 0/0      | 9/9       |
| ShadowToken.sol     | 10/10 | 8/8        | 0/0      | 5/5       |
| Treasury.sol        | 18/18 | 24/24      | 8/8      | 4/4       |

All reported coverage items in these source files were exercised.

**Coverage limitations:**

- `0/0` branches means no branches were reported in that file.
- These percentages do not establish complete coverage of inherited OpenZeppelin implementations.
- The report also includes the invariant handler, which is test infrastructure.
- Coverage confirms execution, not assertion quality, correctness, or security.
- The accounting invariants cover controlled ETH and SHDW flows, not arbitrary token behaviour or the full governance lifecycle.

---

## Security Assumptions and Known Limitations

- **Initial voting concentration:** The deployer receives the complete initial SHDW supply. This is a portfolio simplification, not a decentralised distribution model.
- **Short governance timings:** The configured development timings are unsuitable for production participation and review.
- **Deployment configuration:** Treasury ownership and Timelock roles must be configured correctly. Additional proposer or admin privileges may undermine the intended governance chain.
- **Fixed Treasury ownership:** An incorrect owner cannot be repaired through an ownership transfer. The constructor accepts a nonzero address without proving that it is a correctly configured Timelock.
- **Governance authority:** Successful governance can authorise Treasury payments. The system does not determine whether an approved payment is economically sound.
- **Non-expiring approvals:** Ready operations do not automatically expire and may execute after circumstances change.
- **Token compatibility:** `SafeERC20` handles return-value conventions but cannot make arbitrary malicious, rebasing, fee-charging, or upgradeable tokens safe.
- **Forced or untracked balances:** The handler accounting model does not cover unsolicited balance changes outside its actions.
- **Limited invariant scope:** The current invariant campaign tests Treasury accounting, not governance liveness, malicious callbacks, or all privileged-role transitions.
- **No emergency shutdown:** Emergency response mechanisms are outside the current specification.
- **No external audit:** Passing tests and full measured source coverage are not substitutes for independent security review.

Upgradeable contracts, cross-chain governance, off-chain voting, production token distribution, and formal verification are outside the current project scope.

---

## Deployment Status

This README does not claim a live deployment, verified contract addresses, or a completed governance interface.

Before deployment, the project requires a deployment workflow that configures and verifies the authority model, including removal of temporary administrative privileges after role configuration.

The integration fixture demonstrates the tested configuration but is not a deployment script.

---

## Portfolio Focus

This project demonstrates:

- Solidity governance and Treasury architecture.
- OpenZeppelin voting and Timelock integration.
- Delegation and timestamp-based voting checkpoints.
- Access-control configuration and trust-boundary analysis.
- Atomic execution and rollback testing.
- Deterministic, fuzz, and stateful invariant testing with Foundry.
- Independent accounting counters and controlled handler design.
- Explicit documentation of assumptions, limitations, and centralisation risks.

**Author:** 0xshdwfx

---

## Licence

The project’s Solidity source files declare the MIT licence through their SPDX identifiers. Third-party dependencies retain their respective licences.
