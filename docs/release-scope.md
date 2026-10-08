# First-release specification decisions

Prepared on 2026-10-07 for
[issue #1](https://github.com/ErickOF/mosaic-async-fifo/issues/1).
The proposed scope and contract publisher below need maintainer confirmation.
This document is not an ASIC release approval or an immutable release artifact.

## Parameter envelope

The proposed first-release envelope is the following five **exact tuples**.
The [profile manifest](../config/parameter-profiles.json) supplies the portable
qualification targets. The table resolves the RTL defaults for `wide_deep`.

| Profile | DATA_WIDTH | DEPTH | SYNC_STAGES | ALMOST_FULL_LEVEL | ALMOST_EMPTY_LEVEL |
| --- | --- | --- | --- | --- | --- |
| minimum | 1 | 2 | 2 | 1 | 0 |
| nominal | 32 | 8 | 2 | 7 | 1 |
| three_stages | 64 | 16 | 3 | 1 | 0 |
| wide_deep | 128 | 64 | 4 | 63 | 1 |
| threshold_edges | 32 | 8 | 2 | 8 | 7 |

This is not the Cartesian product of the listed values or a continuous range.
For example, width 128 with depth 8 is legal RTL, but is outside this proposed
envelope. Legal tuples outside the envelope remain exploratory and require
their own qualification and scope approval before release. They must not be
rejected by the RTL merely because they are outside the release envelope.

The [interface](interface.md#parameters) separately defines structural legality.
Formal-only targets and four-state/fault fixture parameters are verification
models, not additional production release tuples. Small-profile formal results
do not establish proof of the wider production profiles.

Each tuple still needs its applicable coverage, assumption review, CDC/RDC,
mapped storage/synchronizer, timing, power, reliability and physical evidence.
Portable PASS does not release a tuple. A scope change or change to any resolved
parameter must trigger review and requalification of affected evidence.

## Contract ownership and dependency

The selected RTL dependency is `mosaic-common` release `MC20261005V1`, pinned
by the parent gitlink at
`6eff6d3d8e43265ca8eff058077f861ca2d6df95`. The FIFO uses its `counter` and
`dff` modules. Reset synchronization remains an integration responsibility.
That common release does not contain a versioned FIFO ready-valid or
reset-cancellation contract.

The proposed resolution is a FIFO-owned artifact,
[`AFIFO-CHANNEL-V1`](contracts/async-fifo-channel-v1.md), extracted from issue
#1's existing behavior. Its publisher would be `mosaic-async-fifo`, not
`mosaic-common`. This does not create a claim that MC20261005V1 publishes the
contract, and does not add a nonexistent `mosaic-contracts` dependency.

Before adoption, amend issue #1's Dependencies and release criterion referring
to `mosaic-contracts` to identify the FIFO-owned artifact and the separate
common RTL dependency. The alternative is to keep the contract gate BLOCKED
until a separately published shared artifact is identified and reviewed.
Do not silently substitute one publisher for another.

Proposed replacement for the issue's contract dependency paragraph:

> Ready-valid record semantics and destructive reset-cancellation policy must
> match the approved, published `AFIFO-CHANNEL-V1` artifact owned by
> `mosaic-async-fifo`. Pin its immutable repository revision and content hash in
> release evidence. `mosaic-common` MC20261005V1 supplies the reused RTL
> primitives, not this protocol artifact. Integration repositories provide the
> coordinated cancellation/reset controller and domain-local reset release.

Proposed replacement for the issue's contract release criterion:

> Interface fields and protocol/cancellation obligations match the approved,
> published FIFO-owned `AFIFO-CHANNEL-V1` artifact. Its revision, hash and the
> common RTL gitlink are recorded in release evidence.

The contract version label alone is not an immutable reference. Release
evidence must record its approved repository commit and content hash, the
common gitlink, and the selected exact tuple. The existing shared release
collector hashes these documents through `RELEASE_ADDITIONAL_INPUTS`. The
`contract_review` gate must remain open until approval and immutable publication
are recorded. No new dependency manifest or synthetic PASS file is needed.

## Invalid-parameter rejection

Proposed replacement for issue #1's "elaboration-time error" requirement:

> Invalid structural parameter values must be rejected before functional
> execution. A tool may reject them during compilation/elaboration. Event-driven
> simulation may instead terminate with a nonzero exit and the diagnostic
> `async_fifo: invalid parameters` at simulation time zero, before clocked FIFO
> operation. Successful compilation alone does not validate an illegal tuple.

The current RTL uses a generate-time legality condition and an `initial
$fatal` in the illegal branch. Icarus compiles that branch successfully, then
`vvp` exits with status 1 at time zero. This is a time-zero assertion failure,
**not** an Icarus compilation/elaboration failure. The negative campaign records
the actual compile and run phases separately and requires the time-zero
diagnostic. Tools that reject the branch earlier must retain their own phase
and named-diagnostic evidence.

The seven current cases exercise width zero, depth one, non-power-of-two depth,
one synchronizer stage, and three invalid threshold values. Each has a passing
legal payload control. Missing tools, unrelated failures, a late fatal, or a
successful illegal run cannot satisfy this requirement. These cases do not
prove every possible invalid encoding or every commercial tool's behavior.

## Approval and publication record

| Decision | Current state | Evidence needed to close |
| --- | --- | --- |
| Five exact production tuples | PROPOSED | Maintainer scope confirmation |
| FIFO-owned AFIFO-CHANNEL-V1 publisher | PROPOSED | Maintainer confirmation and issue amendment |
| Before-execution rejection wording | PROPOSED | Issue amendment acknowledging time-zero rejection |
| Immutable contract publication | BLOCKED | Approved committed revision and artifact hash |
| ASIC release of any tuple | BLOCKED | Applicable release-checklist gates and release-owner approval |

Specification approval does not approve formal overconstraint assumptions,
coverage exclusions, technology corners, MTBF targets or integration reset
timing. Those reviews remain separate. This branch has not been committed or
published as a release.
