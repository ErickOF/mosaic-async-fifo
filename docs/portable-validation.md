# Initial portable validation

Date: 2026-10-05. Source: uncommitted implementation on
`feature-parameterizable_asynchronous_fifo`. This is development evidence,
not a released source revision or ASIC qualification.

Earlier sections retain historical counts and invocation scope. See
[Simulation Gap Closure](#simulation-gap-closure) for current transaction totals
and [Fault and Unknown Expansion](#fault-and-unknown-expansion) for the latest
automated campaigns. [Coverage Cross Implementation](#coverage-cross-implementation)
records the latest full validation and native cross evidence.

Methodology: MF20260910V1,
`0bd222f827afd802944d5f7e6ebc2ccc3a96f7ea`.
Integration baseline: MC20261005V1,
`6eff6d3d8e43265ca8eff058077f861ca2d6df95`.
This revision is pinned by the `submodules/mosaic-common` gitlink, not by a
separate dependency manifest.

## Executed gates

The following passes were observed both natively and in the built container.
Per-profile status files, logs, netlists and native coverage are under
`reports/<profile>/`, `work/<profile>/`, `reports/container/<profile>/`,
and `work/container/<profile>/`. Full local sweep logs are
`/tmp/mosaic-async-fifo-profiles.log` and
`/tmp/mosaic-async-fifo-container.log`.

| Profile | Width / depth / stages | Accounted accepted / delivered / canceled | Portable gate |
| --- | --- | --- | --- |
| minimum | 1 / 2 / 2 | 1772 / 1766 / 6 | PASS |
| nominal | 32 / 8 / 2 | 11572 / 11559 / 13 | PASS |
| three_stages | 64 / 16 / 3 | 22740 / 22711 / 29 | PASS |
| wide_deep | 128 / 64 / 4 | 86158 / 86051 / 107 | PASS |
| threshold_edges | 32 / 8 / 2 | 11572 / 11559 / 13 | PASS |

All five profiles pass Verible lint/format, Slang, Verilator lint/simulation,
Yosys generic synthesis and EQY equivalence. Minimum additionally passes
complete ABC PDR multiclock safety proof and every implemented formal cover.
Minimum and nominal run nine negative-campaign cases and sixteen four-state
monitor/control cases. Campaigns deliberately use a fixed small Icarus test
configuration rather than inheriting the selected simulation profile. Epoch
accounting excludes traffic during canceled reset-propagation windows.

The clean nominal rerun also passes. Actionlint validates the workflow.
Hosted GitHub Actions is NOT_RUN because no new commit or push has been made.

## Common primitive reuse validation

The FIFO now instantiates two common `counter` modules for binary pointers and
seven common `dff` banks for local Gray, domain-up, status, and read-output state.
The common submodule remains unchanged at MC20261005V1. CDC chains, unreset
payload storage, and the external reset-release contract remain FIFO-owned or
integration-owned as specified in the interface.

A clean native all-profile sweep and a fresh container all-profile sweep both
pass after this refactor. Transfer, cancellation, and wrap counts match the
table above. Minimum again passes complete ABC PDR safety proof and formal cover.
The negative and four-state campaigns include the actual common RTL via
`filelists/rtl.f`. Zero-width declarations use safe fallback sizes only to reach
the required parameter fatal, not to support zero-width operation.

An additional development-only EQY comparison passes for all five profiles
against saved pre-refactor generic netlists. Results are retained in
`reports/<profile>/common_refactor_equivalence/`; saved reference netlists and
comparison configurations are under `/tmp/mosaic-async-fifo-before-common/`.
This comparison excludes unstable generated net names and unused next-binary
aliases from name matching while preserving live architectural state, interface,
and storage checks. Storage bits are joined per word for scalable proofs.
The development reference is not a reviewed or released source revision.

Sweep logs are `/tmp/mosaic-async-fifo-common-profiles.log` and
`/tmp/mosaic-async-fifo-common-container.log`. Comparison logs are
`/tmp/mosaic-async-fifo-common-compare-<profile>.log`. These results do not qualify
ASIC area, power, storage mapping, synchronizer preservation, or CDC/RDC timing.

## PyUVM Enablement

Date: 2026-10-06. The portable gate now includes Verilator PyUVM for every
profile, through the unchanged MF20260910V1 adapter. Both full native and
container portable sweeps pass with PyUVM enabled. Formatting-only Python
updates were followed by fresh five-profile PyUVM runs in both environments.
No RTL or pinned dependency change was required for this enablement.

| Profile | PyUVM accepted / delivered / canceled | In-epoch write / read address wraps | Result |
| --- | --- | --- | --- |
| minimum | 574 / 566 / 8 | 285 / 281 | PASS |
| nominal | 3344 / 3326 / 18 | 417 / 415 | PASS |
| three_stages | 6137 / 6105 / 32 | 382 / 381 | PASS |
| wide_deep | 22215 / 22109 / 106 | 346 / 345 | PASS |
| threshold_edges | 3344 / 3326 / 18 | 417 / 415 | PASS |

Native and container results agree. Per-profile PyUVM artifacts include clean
JUnit, versions, the shared assertion/coverage sources in native coverage, and
separate Python scenario/accounting JSON. The FIFO-aware
`check-pyuvm-evidence.sh` passes each profile in both environments. Development
copies prove rejection of SKIP status, a missing no-bubble scenario hit, and a
missing native coverage database. These controls do not change positive evidence.

The opt-in minimum-profile producer fault test fails at the named shared
`async_fifo.u_checker.u_behavior.input_hold` SVA after checker expansion, as required. Its isolated raw FAIL result
and diagnostic are retained under `reports/pyuvm_assertion_control/minimum/`.
The positive baseline passes. This demonstrates actual checking in PyUVM, not
just successful compilation, but does not close all mutation or vacuity work.

Full sweep logs are `/tmp/mosaic-async-fifo-pyuvm-open-source.log` and
`/tmp/mosaic-async-fifo-pyuvm-container.log`. Fresh PyUVM-only rerun logs are
`/tmp/mosaic-async-fifo-pyuvm-profiles.log` and
`/tmp/mosaic-async-fifo-pyuvm-container-rerun.log`. The assertion-control log is
`/tmp/mosaic-async-fifo-pyuvm-assertion-control.log`. Actionlint and shell syntax
checks pass. Hosted CI and commercial PyUVM remain NOT_RUN. Quantitative coverage
qualification, broader formal/reset scope, and ASIC signoff remain open.

## Assertion Expansion

Date: 2026-10-06. The [assertion inventory](assertion-inventory.md) maps the
nineteen required assertion items to behavioral checks or pending structural
analysis. Actual memory writes/holds and visible heads, live-slot ownership,
qualified output capture and invalid-data hold, exact flag/level prediction,
Gray encoding, init prerequisites, reset-safe state, and sticky peer-down
shutdown are now checked by the shared behavioral layer.

The production functional datapath and both dependency revisions are unchanged.
Simulation uses a passive packing adapter, and formal uses synthesis-excluded
observation wiring. Packed storage history prevents generated-word history
aliasing. Local history-valid bits clear on asynchronous reset, and simulation
reset monitors allow one `1ps` precision tick for NBA settling. These checker
scheduling choices do not introduce physical timing assumptions or CDC waivers.

Fresh native and container all-profile portable sweeps pass. The SV transaction
counts and PyUVM counts match the tables above. All ten per-profile PyUVM
artifact/scenario checks pass. Minimum again passes complete ABC PDR safety
proof and every implemented formal cover. The Icarus parameter/output-negative
and paired X/Z campaigns still pass, but do not execute concurrent SVA.

Four focused minimum-profile observation-fault controls pass both natively and
in the container. Each uses the complete unmodified SV regression as its
positive baseline and must hit its named assertion:

| Observation fault | Required first detector | Result |
| --- | --- | --- |
| An idle, non-head storage word changes without push | `g_storage[1].storage_hold` | Detected |
| Invalid output data changes without load | `output_idle_hold` | Detected |
| Init remains high without synchronized peer-up | `write_init_prerequisites` | Detected |
| Pointer reset state is corrupted with the write clock stopped | `write_async_reset` | Detected |

Evidence is under `reports/assertion_controls/minimum/verilator_sim/` and
`reports/container/assertion_controls/minimum/verilator_sim/`. Baseline status
and control status are independent. These cases corrupt checker observations
only, not the FIFO or independent queue, and do not qualify physical faults.
The separate PyUVM producer-offer fault was rerun and fails specifically at
`async_fifo.u_checker.u_behavior.input_hold`. Its raw adapter status remains
FAIL as expected, isolated from positive profiles.

Sweep logs are `/tmp/mosaic-async-fifo-assertions-profiles.log` and
`/tmp/mosaic-async-fifo-assertions-container.log`. Focused-control logs are
`/tmp/mosaic-async-fifo-assertion-controls.log` and
`/tmp/mosaic-async-fifo-assertion-controls-container.log`. The PyUVM fault log is
`/tmp/mosaic-async-fifo-pyuvm-assertion-control.log`. Actionlint and shell syntax
validation pass. CI is configured to retain these controls, but hosted GitHub
Actions remains NOT_RUN because no commit or push was authorized.

This closes behavioral implementation of the identified assertion gaps, not
systematic vacuity review, broader formal parameter/runtime-reset scope,
final-stage-only fanout, payload control independence, clock ownership,
combinational crossing audits, or ASIC release qualification.

## Simulation Gap Closure

Date: 2026-10-06. Both testbenches now require the
[reset and phase scenario matrix](verification-plan.md#reset-and-phase-scenario-matrix).
The first startup holds the write clock low before any write edge, with an
explicit reset assertion. The symmetric stopped-read startup is also checked.
Full-FIFO tests exercise write-first and read-first reset assertion separately
from release skew and verify running-peer shutdown.

A dedicated equal-nominal-rate test repeats ten 12 ns read cycles followed by
ten 8 ns cycles against fixed 10 ns write cycles. It verifies elapsed time,
exactly `20 * DEPTH` completed slow and fast read half-periods, five measured
relative-phase ranges, and accepted transfers in both directions. PyUVM also
verifies equal write/read toggle counts over that balanced window. This is
bounded deterministic phase modulation, not an exhaustive jitter model.

All six write/read/both-stopped versus write-first/read-first reset cases start
with a full FIFO and a backpressured valid head. They check asynchronous safe
outputs with no local clock edge, unchanged stopped-clock edge counts, exact
record cancellation, blocked premature startup during staggered restart/release,
and checked delivery of newly generated records after coordinated recovery.
The stopped side remains in reset until its clock resumes.

Fresh full native and container sweeps pass every enabled portable gate for all
five profiles. SV emits all twenty required scenario records per profile.
PyUVM JSON records all required cases and measured phases. Native and container
counts agree. The following table supersedes the earlier transaction-count
tables for the expanded regression, which are retained as historical evidence.

| Profile | SV accepted / delivered / canceled | PyUVM accepted / delivered / canceled | PyUVM in-epoch write / read wraps | Result |
| --- | --- | --- | --- | --- |
| minimum | 2110 / 2088 / 22 | 650 / 626 / 24 | 320 / 308 | PASS |
| nominal | 14956 / 14875 / 81 | 3997 / 3910 / 87 | 495 / 484 | PASS |
| three_stages | 29119 / 28960 / 159 | 7452 / 7288 / 164 | 460 / 449 | PASS |
| wide_deep | 112852 / 112236 / 616 | 27671 / 27047 / 624 | 431 / 422 | PASS |
| threshold_edges | 14956 / 14875 / 81 | 3997 / 3910 / 87 | 495 / 484 | PASS |

The FIFO-specific PyUVM artifact checker passes all ten profile/environment
combinations. Isolated development evidence copies prove rejection of missing
stopped-write startup, read-first assertion skew, phase range 4, and both-stopped
read-first reset hits. An extra slow interval is rejected as an unbalanced drift
window. Positive reports are not modified by these controls.

The four focused HDL observation-fault controls still pass in both environments,
using the expanded SV regression as the positive baseline. The isolated PyUVM
producer-offer fault still fails at the named `input_hold` SVA, not a Python
queue error. Its raw adapter status remains FAIL as expected.

Minimum again passes complete ABC PDR safety proof and all implemented formal
covers. Formal still has only coordinated startup reset: the new runtime-reset
scenarios are simulation evidence, not an expanded formal proof. Quantitative
coverage, exhaustive phase/reset/occupancy crosses, analog metastability,
CDC/RDC/MTBF, and ASIC signoff remain open. No production RTL or pinned dependency
was changed to add these scenarios.

Full sweep logs are `/tmp/mosaic-async-fifo-simulation-gaps-profiles.log` and
`/tmp/mosaic-async-fifo-simulation-gaps-container.log`. Focused-control logs are
`/tmp/mosaic-async-fifo-simulation-gaps-assertion-controls.log` and
`/tmp/mosaic-async-fifo-simulation-gaps-assertion-controls-container.log`.
The PyUVM fault log is
`/tmp/mosaic-async-fifo-simulation-gaps-pyuvm-assertion-control.log`.
Actionlint, shellcheck and Python compilation pass. Hosted GitHub Actions is
NOT_RUN: no commit or push was authorized.

## Fault and Unknown Expansion

Date: 2026-10-07. The declarative campaigns now include 24 negative cases
and 32 four-state cases. This section supersedes earlier opt-in-only PyUVM
fault descriptions. The [verification plan](verification-plan.md#negative-and-four-state-plan)
records exact fixture parameters, detectors and remaining coverage.

The negative campaign requires three positive baselines: the mixed-X/Z payload
test, the no-fault RTL fixture and the full minimum PyUVM regression. Twelve
actual RTL-state faults cover both receiving domains' pointer and domain-up
synchronizers at stage zero and the final stage, full/empty flag mutations,
idle memory corruption and suppression of an accepted memory write. Pointer
and domain-up faults hit named fixture-bounded visibility/capacity/startup
checks. Flag/memory faults hit their named shared prediction/storage SVA.
These are distinct from the four earlier observation-only checker controls.

The automated PyUVM producer-offer fault emits its arrival marker and fails
specifically at `async_fifo.u_checker.u_behavior.input_hold`, not a Python queue
comparison. The unchanged adapter's raw status remains FAIL under the case work
root. Its compact logs, JUnit and versions are archived under
`reports/<profile>/negative_qualification/pyuvm_input_hold/reports/raw-pyuvm/`,
including `raw-status.txt`. The campaign case alone records expected-failure
PASS. Separating that filename from gate `status.txt` prevents the recursive
profile collector from mistaking expected raw failure for a failed positive
gate. No status is rewritten to conceal the simulator result.

Sixteen X/Z injections cover both resets, write valid, read ready, both final
Gray buses and both final domain-up bits. Each has its own disabled-monitor
control proving arrival at the actual checker input. Final-stage unknowns hit
the direct receiving-domain monitor before public flag contamination. The
payload baseline delivers 24 queued records across six fill/drain bursts,
prefetch, stalls and wraps. All eight all/mixed/sparse X/Z patterns must pass
three times while public flags, levels and initialization remain known.

The RTL-state and PyUVM fault fixtures use minimum parameters. Icarus uses fixed
8-bit, depth-four, two-stage parameters. Repeating these campaigns in the outer
nominal profile does not expand fault parameter coverage. Nested Make controls
clear the inherited disabled-flow list and recompute minimum-profile policy.
No shared methodology or common primitive source is modified.

Isolated counterfactual manifest copies exercise the unchanged campaign runner
in both environments. Each keeps a passing baseline and must produce aggregate
FAIL with the following classification, without overwriting positive reports:

| Counterfactual | Required rejection |
| --- | --- |
| A negative executes the passing RTL binary without a fault | `escaped_fault` |
| An actual flag fault has the wrong required diagnostic | `unexpected_failure` |
| A negative invokes an unavailable binary | `infrastructure_failure` |
| An unknown-detection case is compiled with its monitor disabled | `escaped_fault` |

Native fixtures and reports are under `work/fault-classification-MGfjH9/`.
Container equivalents are under `work/fault-classification-container/`.
These are local development controls, not a complete recurring fault sweep.
Seven invalid-parameter guards and output corruption remain in the standard
negative campaign. Watchdogs, escape sentinels, missing tools and wrong
diagnostics cannot satisfy expected-failure qualification.

Fresh full native and container sweeps pass all enabled portable gates for all
five profiles, including both aggregate profile summaries. All ten positive
PyUVM artifact/scenario checks pass, and SV/PyUVM transaction totals match the
Simulation Gap Closure table above. Both minimum and nominal pass every one
of the 24 negative and 32 four-state cases in each environment. The four
observation-fault controls also pass again in both environments. Minimum again
passes complete ABC PDR safety proof and all implemented 64-step covers.
All five profiles pass RTL-to-generic-netlist equivalence. Formal scope is
unchanged: no runtime-reset, four-state or analog proof is implied.
Actionlint, shellcheck, Python compilation and whitespace checks pass. All
new/updated verification sources pass the four-space indentation check, and
the changed HDL/predicate files match the pinned Verible formatter.

Full sweep logs are `/tmp/mosaic-async-fifo-faults-profiles-final.log` and
`/tmp/mosaic-async-fifo-faults-container-final.log`. The four observation-control
logs are `/tmp/mosaic-async-fifo-faults-assertion-controls.log` and
`/tmp/mosaic-async-fifo-faults-assertion-controls-container.log`. Both dependency
revisions and the production functional RTL remain unchanged. Other fault
polarities, transients, larger stage/depth/address sweeps, quantitative coverage,
antecedent/vacuity closure, licensed four-state SVA, analog metastability and
ASIC signoff remain open. Hosted GitHub Actions is NOT_RUN because no commit
or push was authorized.

## Coverage Cross Implementation

Date: 2026-10-07. The [HDL model](coverage-model.md) now represents all twelve
required coverage items in twenty native cross families. SV and PyUVM execute
the same passive model. Formal reuses the state/history observations with a
startup-only minimum-profile reachability target set, not real-time observers.
Production functional RTL and both pinned dependencies are unchanged.

Generated `cover property` loops merged native bin identities in the pinned
simulator. Covergroups preserve each bin, but coverpoint `iff` does not qualify
a cross, and cross `iff` is unsupported. The final model uses separate groups
with guarded `sample()` calls. Earlier development databases with unguarded
cross counts are superseded and must not be used as qualification evidence.
The collector verifies every identity and count conservation against component
coverpoints and ten independent HDL state-event counters. It never drops zeros.

Fresh full native and container portable sweeps pass all five profiles. All
twenty positive simulator/profile/environment artifact checks pass. Native and
container parameters, qualified event counts and individual cross-bin counts
agree exactly. Transaction totals remain those in Simulation Gap Closure.
The following are raw hit/bin counts, including padding and unreviewed
unreachable combinations, not percentages or quantitative release PASS:

| Profile | SV raw hit/bin count | PyUVM raw hit/bin count | Artifact integrity |
| --- | --- | --- | --- |
| minimum | 113 / 185 | 111 / 185 | VALID |
| nominal | 273 / 417 | 271 / 417 | VALID |
| three_stages | 707 / 1033 | 702 / 1033 | VALID |
| wide_deep | 4628 / 9481 | 4006 / 9481 | VALID |
| threshold_edges | 270 / 417 | 268 / 417 | VALID |

Real stimulus holes are visible independently of padding. Wide/deep SV reaches
2155/4096 write-address pairs and 2073/4096 read-address pairs; PyUVM reaches
1837/4096 and 1775/4096 respectively. All addresses are observed, but these
Cartesian pairs need broader stimulus, not automatic waivers. Partially occupied
reset cases with inactive clocks and several initialization/clock/occupancy
combinations are also unhit. Exact profile-specific legal-bin review is pending.

Both minimum formal proof and scoped cover tasks pass again. Two additional
assertions prove the wrap-phase invariants used to retain reachable formal
pairs. All four pairs still exist in simulation, with two hit and two zero per
port. This does not approve native-bin waivers or extend formal runtime-reset,
parameter, analog or four-state scope. The 24 negative and 32 four-state cases
pass for minimum and nominal in both environments. All four focused observation
faults are still detected after a passing full baseline in each environment.

Eight isolated native-database controls pass using both native and container
minimum fixtures. They reject missing bins, old-five-counter-only evidence,
duplicates, wrong depth shape, SKIP status and inflated state-cross counts. An
all-zero cross/component/event-counter fixture remains VALID with qualification
and vacuity NOT_RUN, demonstrating that integrity is not threshold enforcement.
Positive reports are untouched. Actionlint, shellcheck, Python compilation,
Verible four-space formatting and whitespace checks pass.

Full sweep logs are `/tmp/mosaic-async-fifo-crosses-profiles.log` and
`/tmp/mosaic-async-fifo-crosses-container.log`. Focused-control logs are
`/tmp/mosaic-async-fifo-crosses-controls.log` and
`/tmp/mosaic-async-fifo-crosses-controls-container.log`. Per-flow databases and
`cross-coverage.json` live in the usual native/container profile report roots.
The native sweep script and GitHub Actions retain the model-integrity checks
alongside the separate PyUVM scenario checks.

MF20260910V1 does not qualify the native `covergroup` metric. Quantitative
qualification remains disabled and mandatory for release. Shared-parser support,
uncovered-bin stimulus, reviewed exclusions, deficient-threshold enforcement,
systematic assertion antecedent/nonvacuity review and candidate warning-waiver
approval remain open. Hosted GitHub Actions and commercial coverage are NOT_RUN.
No commit, push, release identifier or coverage/signoff approval was created.

## Container identity

Built image:
`sha256:2c542500db1bc36b54fdfa8a754ace0cc22695c626940e1a9e1bd9a160e75338`.
The Dockerfile pins the base image and includes the exact shared methodology
via a build context. Execution uses the invoking UID/GID and separate output
roots. The tagged local image is not a published release artifact.

## Fail-closed release control

`make PROFILE=minimum RELEASE_ALLOW_DIRTY=enabled
RELEASE_EXECUTION_CONTEXT=diagnostic release-manifest` rejects missing
`vc_lint/status.txt` through `RELEASE_SUPPLEMENTAL_GATES`.
No publishable manifest was produced. The dirty override was used only to
exercise rejection after bypassing the earlier dirty-source check.

## Formal expansion (2026-10-07)

This snapshot supersedes the minimum-only formal scope in the earlier sections.
No prior minimum result was generalized. The existing mosaic-flow adapter runs
the separate `config/formal-profiles.json` without changes to either pinned
dependency. All nine exact targets pass complete ABC PDR safety and separate
SMT cover mode natively and in the pinned portable container. Cover mode has
a 128-global-step bound, distinct from complete proof. Both tasks time out
after 600 seconds and fail closed.

| Exact profile | Complete proof, native/container | Reached elaborated covers, each environment | Latest witness step |
| --- | --- | --- | --- |
| depth4 | PASS / PASS | 112 | 47 |
| depth4_edges | PASS / PASS | 111 | 47 |
| depth2_three_stages | PASS / PASS | 81 | 53 |
| reset_depth2 | PASS / PASS | 89 | 41 |
| reset_depth4 | PASS / PASS | 130 | 45 |
| reset_three_stages | PASS / PASS | 101 | 49 |
| delayed_reset_depth2 | PASS / PASS | 97 | 41 |
| delayed_reset_depth4 | PASS / PASS | 138 | 45 |
| delayed_reset_three_stages | PASS / PASS | 109 | 49 |

Counts are each task's post-elaboration property inventory, not native HDL
cross-bin counts or a merged coverage percentage. Every retained cover has a
PASS database status and an existing required witness trace. Threshold settings
change the generated legal transition inventory, accounting for the 111-target
threshold-edge inventory versus 112 in depth4.

Runtime reset can assert independently of either clock. Either assertion
immediately cancels the independent reference addresses and offer history.
A new epoch requires overlapping raw resets; accepted writes need not wait
for both initialization outputs. Shared checker history also clears on
asynchronous assertion. Reset state is checked at a settled global observation
even while a local clock is held. Peer shutdown is proved after the documented
number of actual peer edges. Covers reach empty/partial/full and stalled-head
cancellation, unilateral/joint reset, either/both clocks held, peer-down in
both directions and repeated fresh-epoch write/read recovery.

Each delayed target independently permits one extra coherent first-stage edge
for both Gray pointers and both domain-up markers. Eight additional witnesses
require genuinely stale deferred values and forced capture despite further
defer requests. Production elaboration retains its exact attributed pipeline;
the helper and formal-only parameters do not add production registers or ports.
See [formal model](formal-model.md) for the full assumptions and scope.

`check-formal-evidence.py` verifies each profile's applied parameters, PDR engine,
current staged source hashes, separate proof/cover PASS statuses and all cover
traces using the SymbiYosys property database. It writes per-profile
`formal-evidence.json`. Eight disposable artifact controls pass natively and in
the container: valid positive, combined SKIP, wrong parameters, missing proof,
unreached cover, missing trace, stale source and unqualified bounded engine.
These are integrity controls, not formal RTL mutation or full vacuity closure.

Native evidence is under `/tmp/mosaic-formal-expansion/{reports,work}/<profile>/`,
with aggregate log `/tmp/mosaic-formal-matrix.log`. Container evidence is under
`reports/formal-container/<profile>/` and `work/formal-container/<profile>/`,
with aggregate log `/tmp/mosaic-formal-container.log`. These local artifacts
are not committed release evidence. CI uses `reports/formal/` and `work/formal/`
for its native matrix and uploads databases, staged sources and witness traces.

The original five portable profiles were rerun natively. All enabled lint,
format, elaboration, synthesis, equivalence, SV and PyUVM flows pass; minimum
also passes complete startup proof and all 71 covers, latest witness step 43.
Minimum/nominal negative and four-state campaigns pass again. Transaction and
native cross hit totals match the prior coverage snapshot. Logs are
`/tmp/mosaic-formal-portable-regression.log` and
`/tmp/mosaic-formal-portable-evidence.log`.

Workflow actionlint, Python syntax compilation, manifest validation and
`git diff --check` pass. Hosted GitHub Actions is still NOT_RUN: no commit or
push was created. Integration-owner assumption review, systematic assertion
non-vacuity, wider/deeper/stage-four formal proofs, arbitrary capture delays,
physical CDC/RDC, Gray timing, analog MTBF and ASIC signoff remain open.

## Specification reconciliation snapshot, 2026-10-07

The [decision record](release-scope.md) proposes five exact production tuples,
not a Cartesian product. Their resolved parameters were checked against the
profile manifest, including `wide_deep`'s default thresholds 63 and 1. No
profile, hardware parameter legality or ASIC release approval was changed.
The proposed FIFO-owned AFIFO-CHANNEL-V1 contract retains the issue's handshake,
external reset release and destructive cancellation obligations. Scope/publisher
approval, issue amendment and immutable publication are still pending.

The seven Icarus invalid-parameter cases now report successful compilation and
`expected_assertion_failure` on execution. Their diagnostic requires the named
fatal at `Time: 0` in `g_invalid_parameters`. Both 24-case native campaigns
(`minimum`, `nominal`) and a 24-case container minimum campaign pass with that
requirement. Container evidence is isolated in
`reports/spec-container/minimum/negative_qualification/` and
`work/spec-container/minimum/negative_qualification/`. The pinned portable image
is unchanged. Logs are `/tmp/mosaic-spec-negative-native.log`,
`/tmp/mosaic-spec-negative-nominal.log` and
`/tmp/mosaic-spec-negative-container.log`.

The qualification-control script reuses mosaic-flow's classifier for 42 checks:
each of seven actual diagnostics passes, and five altered outcomes per case
(late fatal, missing time, wrong diagnostic, successful illegal run, missing
simulator) fail with the expected classifications. These integrity controls
do not approve a contract or prove every illegal encoding. Run them with:

```sh
bash .github/scripts/check-qualification-controls.sh
```

That script passes the minimum 24-case negative and 32-case four-state campaigns
before all 42 classifier checks. Its execution log is
`/tmp/mosaic-spec-controls-native.log`.

The shared release input collector hashes the interface, proposed scope and
contract through `RELEASE_ADDITIONAL_INPUTS`. Its mandatory `contract_review`
and ASIC gates remain unchanged, with no fabricated PASS artifact. Manifest
validation, selected-profile flow configuration, actionlint and
`git diff --check` pass. No commit, push or hosted GitHub Actions run was made.

## Hosted CI timeout investigation, 2026-10-07

Both hosted runs use revision `6fbba188b22ebce249196234f33f61a767de3d85`:

- [Push run 37730251982](https://github.com/ErickOF/mosaic-async-fifo/actions/runs/37730251982)
  passes, including every native portable/formal job and the full container job.
- [PR run 37730334702](https://github.com/ErickOF/mosaic-async-fifo/actions/runs/37730334702)
  passes all five native portable jobs, all nine native formal jobs, the portable
  container sweep and assertion controls. Eight container formal profiles pass.
  The `delayed_reset_depth4` container proof reaches the 600-second timeout
  before ABC PDR returns a result. Its cover task is not run afterward, and the
  container job correctly fails. No assertion counterexample is reported.

The PR's retained container artifact is `11530816740`. Its eight successful
formal profiles pass the current source/parameter/proof/witness checker.
The failed profile remains `TIMEOUT` in SymbiYosys and `FAIL` at the combined
flow. The checker rejects that real artifact as `Combined flow did not pass`.
Source hashes match the current RTL. Local downloaded artifacts are isolated
at `/tmp/mosaic-pr2-failed-container-artifacts/`, and the full job log is
`/tmp/mosaic-pr2-container-job.log`.

The fix increases only the proof wall-clock budget to 1200 seconds. Complete
ABC PDR, assertions, assumptions, all nine profiles and the 128-step cover bound
are unchanged. Cover keeps its 600-second budget. Native formal jobs allow
40 minutes and the combined container job allows 75 minutes. Only the
formal-only container sweep switches to `PROFILE_JOBS=1` to avoid contention
between profiles on the same runner. Portable execution retains two concurrent
profiles. Timeouts, UNKNOWN and unreached covers still fail closed.

A fresh full nine-profile formal sweep passes in the pinned container with a
two-CPU quota, sequential formal profiles and isolated
`reports/ci-formal-budget/` and `work/ci-formal-budget/` roots. The image remains
`sha256:2c542500db1bc36b54fdfa8a754ace0cc22695c626940e1a9e1bd9a160e75338`.
Its log is `/tmp/mosaic-ci-formal-budget-regression.log`. Every profile passes
complete proof and all selected covers. The source/parameter/proof/witness
checker passes all nine results, with witness counts and steps matching the
earlier formal scope table. All eight disposable evidence controls pass again.
The previously timed-out profile completes proof in 435 seconds and cover in
166 seconds, reaching all 138 witnesses. The actual failed PR artifact is still
rejected, not reclassified. Actionlint and `git diff --check` also pass.

The failed PR run is not relabeled as passing. Local validation preceded
commit creation, and the revised configuration has not been pushed or tested
in hosted CI. The checklist's hosted workflow item remains open despite the
original passing push run. ASIC qualification and specification approvals
remain separate open gates.

## Standalone flow policy, 2026-10-08

The owner has disabled `yosys_synthesis` and `eqy_equivalence` at the FIFO
unit level. Both flags are disabled in `config/flows.mk`, and both flow IDs
are excluded from all five production profile lists. No parameter tuples,
RTL, shared adapters or dependency revisions were changed. Retained synthesis
and EQY collateral remains available for future re-enablement.

Both manifests validate, the portable matrix is deterministic, and resolved
flow policy validates for all five portable and nine formal-only targets.
All nine formal-only targets still require `symbiyosys_formal`. The original
minimum profile passes complete proof and all 71 cover witnesses, with the
latest witness at step 43. Its source/parameter/proof/witness check passes.
Yosys remains necessary for formal model preparation, independently of the
disabled standalone synthesis flow.

A fresh five-profile native `open-source` sweep passes with `PROFILE_JOBS=2`.
Every profile records `PASS` for its enabled flows and `SKIP` for both disabled
standalone flows. SystemVerilog and PyUVM evidence integrity checks pass for
all five profiles, and all eight cross-artifact failure controls pass again.
The negative and four-state campaigns pass where enabled. Reports and work
products are isolated under `reports/unit-flow-policy/` and
`work/unit-flow-policy/`; the run log is
`/tmp/mosaic-unit-flow-policy-regression.log`. Native cross evidence is valid,
but quantitative closure remains open. Actionlint and `git diff --check` pass.

Native explicit targets and a five-profile Docker `open-equivalence` sweep
return policy `SKIP` with both `YOSYS_CMD` and `EQY_CMD` set to nonexistent
paths. The retained EQY prerequisite also skips synthesis. All ten container
statuses are `SKIP`, with no synthesis or EQY adapter logs generated.
This focused container check does not claim a new full container regression.
Its evidence is isolated under `reports/unit-flow-policy-container/` and
`work/unit-flow-policy-container/` using the existing pinned portable image.

Earlier synthesis/equivalence PASS snapshots remain historical. Their results
are not current-policy PASS claims. These skips do not waive technology-mapped
storage/synchronizer, CDC/RDC, timing, power, MTBF or ASIC release obligations.
These results were collected before commit creation. The updated policy has
not been pushed or tested in hosted GitHub Actions.

## Remaining evidence

See the original-format [release checklist](release-checklist.md) and
[verification plan](verification-plan.md). In particular, passing portable
gates do not close quantitative coverage, all formal/reset requirements,
contract approval, licensed CDC/RDC/STA/power, MTBF or mapped storage and
synchronizer preservation.
