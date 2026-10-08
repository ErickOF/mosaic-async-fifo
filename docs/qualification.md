# Qualification boundaries

This branch implements issue #1's initial RTL and portable verification. It has
no release approval. The [release checklist](release-checklist.md) remains the
authoritative worklist.

## Required before release

- Approval of the exact first-release envelope and contract publisher in the
  [specification decision record](release-scope.md), corresponding issue
  amendments, and immutable publication of the approved channel contract.
  MC20261005V1 is the RTL dependency, not a protocol/cancellation artifact.
- Expanded parameter, payload, reset, assertion, coverage and fault campaigns.
- Review of the nine completed multiclock proof/cover targets and their runtime
  reset/variable-capture assumptions. Wider production profiles and physical
  propagation remain outside those [formal models](formal-model.md).
- Qualified VC Lint, CDC and RDC reports for both Gray buses and domain-up bits.
- Exact synchronizer depth and stage fanout preservation after mapped synthesis.
- Characterized dual-clock storage and read-during-write behavior.
- Real mapped endpoint delay/skew constraints, setup/hold and recovery/removal.
- MTBF for every crossing bit with library constants, frequency, transition rate,
  resolution time, PVT and an approved system reliability target.
- Representative activity/annotation review and PrimePower PPA characterization.
- Product-specific DFT, power intent and physical requirements.

No latency number, PPA number, MTBF number, or target technology is inferred from
generic simulation, Yosys, or a public exploratory platform. SVA/formal do not
simulate analog metastability. Synchronizer attributes alone do not establish
preservation or safe placement.

## Evidence classifications

PASS applies only to an executed gate and its exact parameters/model.
NOT_RUN means the applicable gate has no execution evidence.
BLOCKED means a prerequisite such as a contract, tool, PDK, budget, or qualified
adapter is missing. Portable policy SKIP does not replace either release status.

The invalid-parameter campaign reports successful Icarus compilation followed
by `expected_assertion_failure` at time zero. That runtime rejection is not
an `expected_elaboration_failure`. The diagnostic must establish time zero,
not merely any eventual simulation failure. The issue wording amendment remains
pending until this portable before-execution policy is approved.
