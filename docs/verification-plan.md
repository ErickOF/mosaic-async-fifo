# Verification plan

[Return to the documentation index](README.md).

## Verification objectives

Verify the [interface contract](interface.md) independently of DUT pointers and
storage. Portable correctness is separate from analog metastability and ASIC
CDC/RDC, timing, power, and physical signoff.

## Verification environments

| Environment | Top or input | Purpose |
| --- | --- | --- |
| Verilator | `async_fifo_tb` | Independent transaction queue, assertions, native HDL coverage |
| PyUVM / Verilator | `async_fifo`, `AsyncFifoTest` | Separate public-port queue, dual-clock/reset scenarios, the same bound SVA and HDL coverage |
| Verilator fault fixture | `async_fifo_fault_tb` | Actual synchronizer, flag and storage mutations with a passing no-fault baseline |
| Icarus | `async_fifo_four_state_tb` | Mixed X/Z transport, external and final-stage unknown detection, parameter rejection, output fault |
| SymbiYosys | `async_fifo_formal` | Independent clocks, reference storage and pointer safety |
| EQY | `async_fifo` | RTL versus generated generic netlist, explicit clock-edge modeling |
| Static frontends | `async_fifo` | Verible, Slang, Verilator, Yosys |

PyUVM is enabled for all five profiles. Commercial adapters need site qualification.

## Requirements traceability

| ID | Requirement | Current evidence | Remaining work |
| --- | --- | --- | --- |
| FIFO-01 | Legal widths, power-of-two depths, stages, thresholds | Five exact proposed production tuples and seven time-zero invalid-parameter cases | Scope approval and applicable ASIC qualification. Other legal tuples remain exploratory, not a released cross-product |
| FIFO-02 | FIFO ordering and no loss/duplication | Independent SV/PyUVM queues and reset-aware formal reference memory in explicitly selected profiles | Wider/deeper formal configurations and watched-tag abstraction |
| FIFO-03 | No overflow/underflow | Scoreboard bounds, formal occupancy checks | CDC tool confirmation under propagation abstraction |
| FIFO-04 | Pointer ownership and Gray single-bit transitions | Shared checker in normal simulation, PyUVM, and formal | Structural mapped-netlist crossing audit |
| FIFO-05 | Registered, stable head and full-rate pop | Output hold/capture/idle SVA, per-word visible-head checks, queue comparison, full-visible burst | Structural registration audit, wider fault controls and antecedent coverage |
| FIFO-06 | Conservative levels and threshold boundaries | Per-clock pre-edge occupancy checks and threshold comparison | Symbolic threshold and all stage/depth formal coverage |
| FIFO-07 | Coordinated reset cancellation | SV/PyUVM cancellation accounting and symbolic runtime-reset reference epochs, with empty/partial/full, stopped-clock and fresh-recovery witnesses | Integration-owner reset-contract review, broader release profiles and physical reset-window signoff |
| FIFO-08 | One-sided reset cannot self-recover | SV/PyUVM unilateral/skewed resets, shared sticky-shutdown checks and formal peer-shutdown obligations under explicit visibility assumptions | Systematic antecedent review, RDC signoff, broader stage/depth and physical pulse/timing qualification |
| FIFO-09 | Independent/stopped clocks | SV/PyUVM fast-write/read, equal/coincident edges, equal-nominal-rate bidirectional phase drift, drifting periods, stop/restart, and both stopped-startup directions | Finer phase/seed sweep and latency histogram |
| FIFO-10 | Unknown payload is not control | Eight all/mixed/sparse X/Z patterns, queued-record ordering, stalled-head case equality and known flags/levels across wraps | Wider width/depth/pattern cross-product and licensed X-propagation |
| FIFO-11 | Illegal controls are detected | X and Z on both resets, write valid, read ready, both final Gray buses and both final domain-up bits, each with a disabled-monitor arrival control | Licensed four-state SVA, intermediate/transient faults, clock unknowns and broader parameter coverage |
| FIFO-12 | Checking detects faults | Twelve actual RTL synchronizer/flag/memory faults, parameter/output negatives and automated PyUVM input_hold fault with passing controls | Other fault polarities, transient/stage/address/parameter sweeps, vacuity and inequivalent-netlist controls |
| FIFO-13 | Physical synchronization assumptions hold | RTL attributes and documented chain ownership | Mandatory licensed CDC/RDC, preservation, Gray delay/skew, MTBF evidence |

## Simulation plan

The deterministic independent generators hold producer offers based on the
preceding sampled handshake, not the updated ready flag. The scoreboard samples
occupancy once per timestamp so coincident clock edges use the same pre-edge
occupancy. It compares complete opaque records and counts accepted, delivered,
and canceled records. Transfers during a canceled reset-propagation window are
excluded from epoch accounting, as their delivery is not guaranteed.

Scenarios include fill/full stalls, skewed reset assertion and release, startup
with either clock stopped, a no-bubble full-visible burst, partial/stalled reset,
four fixed ratios, equal-nominal-rate phase drift, 100 pseudorandom period
intervals, individual clock stops, six stopped-clock reset cases, many wraps,
one-sided resets in both directions, and coordinated recovery. Seeds are
`0x53a912f1` and `0x7681c032`. The scenario matrix below is mandatory in both
SV and PyUVM, with SV emitting `SCENARIO_PASS` records only after its checks.

The regression requires nonzero full, empty, and output-stall visits and at least
ten aggregate wraps per direction. Those counters do not close all functional,
assertion, or code coverage goals.

## PyUVM Plan

`AsyncFifoTest` creates a PyUVM environment and scoreboard. Its BFM schedules
independent write/read clock edges, samples both ports before coincident edges,
and waits for HDL settling before continuing. The reference queue uses accepted
port transfers only, never DUT pointers, memory, or common primitive internals.
Bounds use pre-edge occupancy and comparisons use the complete opaque payload.
Dedicated Python RNGs use seed `0x53a912f1` with distinct source, sink, and payload
streams, so reader timing does not consume producer payload randomness.

All profiles run full and partially filled reset cancellation, both skewed
assertion orders and skewed release, both stopped-clock startup directions,
no-bubble visible read bursts, fast-write/read, exactly coincident equal clocks,
coprime clocks, dedicated equal-nominal-rate phase drift, 50 drifting-period
intervals, both individual clock stops, all six stopped-clock reset cases, and
one-sided reset shutdown/recovery in both directions.
Each epoch reset removes pending records from the queue and accounts them as
canceled. Comparison is suspended in the canceled propagation window and resumes
only after coordinated startup. A unilateral release must not reinitialize.

The test requires all implemented scenario counters and at least ten address
wraps per direction within epochs, not counts that falsely wrap across resets.
Final accepted equals delivered plus canceled, and the reference queue is empty.
Bounded waits and a 20 ms simulation timeout reject stalled regressions.
`functional-coverage.json` records actual hit counts and parameter identity.
These counts complement native HDL coverage and do not close the draft 90%/100%
release coverage policy, all parameter combinations, phase seeds, or SVA vacuity.

## Reset and phase scenario matrix

| Required scenario evidence | Stimulus and checks |
| --- | --- |
| `stopped_startup_write`, `stopped_startup_read` | The first startup holds the write clock low before any write edge. The symmetric read-stop case uses a later coordinated reset. Release only the running side first, verify both interfaces remain uninitialized and blocked, then resume the stopped clock and release its reset on a local falling edge. |
| `skewed_assert_write_first`, `skewed_assert_read_first` | Start full with a valid, backpressured head. Assert one reset, check its asynchronous safe outputs, keep the peer clock running long enough to observe shutdown, verify its init/transfer permission falls, then assert the peer reset and recover. Assertion skew is distinct from release skew. |
| `equal_phase_drift`, `equal_drift_write`, `equal_drift_read` | Keep write cycles at 10 ns. Repeat ten 12 ns read cycles followed by ten 8 ns cycles, for `DEPTH` repetitions, while transferring randomized traffic. Check completed slow/fast intervals and elapsed time, so the mean read rate equals the write rate. |
| `equal_drift_phase_0` through `equal_drift_phase_4` | Count actual read rising-edge phase modulo the 10 ns write period in five 2 ns ranges. All ranges must be visited, with phase walking in both directions. Phase is measured from generated edges, not credited from the requested clock mode. |
| `equal_drift_slow_edges`, `equal_drift_fast_edges` | Each must count exactly `20 * DEPTH` completed read half-periods. PyUVM additionally verifies equal write/read toggle counts over the balanced window. |
| `reset_stop_w_w_first`, `reset_stop_w_r_first` | Start full with a held head, stop the write clock low, then exercise both reset assertion orders. |
| `reset_stop_r_w_first`, `reset_stop_r_r_first` | Repeat both assertion orders with the read clock stopped low. |
| `reset_stop_both_w_first`, `reset_stop_both_r_first` | Repeat both assertion orders with both clocks stopped low, advancing real time without manufacturing clock edges. |

Every stopped-clock reset checks local safe outputs after assertion without
requiring a local edge, unchanged stopped-clock edge counts, and exact pending
record cancellation. The running side, or the first-reset side when both clocks
were stopped, resumes/releases first. The other clock stays stopped with reset
asserted: both endpoints must remain blocked. After both clocks resume and reset
releases on their respective falling edges, initialization must complete and
newly generated records must pass the independent queue before the case is
credited. Bounded waits/timeouts prevent a stuck recovery from passing.

Reset assertion is explicit at initial startup rather than relying on simulator
power-on register values. The stopped side's reset remains asserted until its
clock resumes, respecting externally synchronized release. Reset holds are long
enough for the running peer to observe shutdown. These are not short-pulse,
recovery/removal, analog metastability, or structural RDC tests.

The drift case uses bounded deterministic period modulation with equal nominal
and average rates. Exactly equal constant periods would retain a fixed relative
phase. It does not claim an exhaustive jitter spectrum, continuous/sub-nanosecond
phase sweep, or every occupancy/backpressure/reset-duration cross. The six-case
matrix specifically closes the requested stopped-clock/assertion-order gaps,
not arbitrary combinations or the runtime-reset formal proof.

## Assertion plan

The [assertion inventory](assertion-inventory.md) maps all nineteen issue
requirements to named behavioral checks or remaining structural analysis.
`verif/properties/async_fifo_predicates.svh` supplies shared prediction, reset,
Gray-step and known-control predicates. `async_fifo_sva` owns the checker.
Normal simulation and PyUVM bind through a passive storage-array packing adapter.
Formal explicitly instantiates the same behavioral checker because Yosys does
not elaborate bind. No production functional RTL or pinned dependency changes
are needed by the observation logic.

Checks cover canonical handshakes, exact local pointer/Gray/flag/level prediction,
thresholds, initialization, reset-safe state, qualified output capture and idle
holds, actual per-word storage writes/holds, live head/slot ownership, and sticky
peer-reset shutdown. Storage history is not reset-masked. Local history-valid
bits clear asynchronously so stopped-clock reset cancels old local obligations.
Ownership is qualified by a live, uncanceled epoch. Cross-domain observation
signals are verification-only and do not introduce functional hardware crossings.

The simulation-only asynchronous reset monitors allow one `1ps` precision tick
for digital scheduling and also run while the local clock is stopped. Formal
uses settled global reset observations that also require no local clock edge.
Neither substitutes for recovery/removal,
reset pulse-width, or structural RDC analysis. Final-stage-only fanout, payload
control independence, exclusive register clock ownership, and absence of hidden
combinational crossings still need structural evidence.

The Icarus branch uses the same known-control and final-synchronizer predicates
in immediate monitors. Public controls include almost flags and level estimates.
Final Gray/domain-up unknowns are checked directly before the public controls,
so detection does not rely on subsequent contamination of full/empty flags.
It does not run concurrent SVA. It validates both stimulus arrival with monitors
disabled and detection with monitors enabled. Native Verilator is two-state and
cannot supply this evidence by itself.

## Formal plan

The original `minimum` profile retains its startup-only proof. The independent
`config/formal-profiles.json` adds nine precisely scoped targets for depth four,
two-bit payload/threshold endpoints, three stages, runtime cancellation and
variable capture. See [formal model](formal-model.md) for exact profiles,
assumptions, reachability obligations and reproduction commands.
Both clocks toggle through reset startup, then independently toggle or hold on
symbolic global steps. Neither is assumed to keep running during operation.
The source is assumed to hold its offer when backpressured. Read readiness and
payload are otherwise symbolic.

Separate reference addresses and storage follow only accepted transfers. Checks
cover ordering at every valid head, occupancy bounds, conservative estimates,
pointer advancement, Gray steps, actual storage writes/holds, flag/level
prediction, initialization, qualified output capture/idle holds and
stalled-output stability. ABC PDR is used for an unbounded safety proof.
SMT cover mode has depth 128 and must reach full,
write/read transfer, output stall, initialized empty, and both pointer wraps.

Startup-only targets include one coordinated reset and fixed startup edges.
Runtime targets allow either reset to cancel an initialized epoch at arbitrary
occupancy, including while clocks hold. Independent reference addresses clear
on either raw reset, and recovery needs overlapping resets. Peer shutdown is
checked after actual destination edges under the explicit reset-visibility
contract. Variable targets independently allow each coherent first-stage word
to defer capture by one edge, with eight required delay witnesses. Each exact
target must have its own complete proof and every implemented cover witness.
Wider/deeper portable configurations, arbitrary capture latency, assertion
non-vacuity, conditional liveness, analog MTBF and physical CDC/RDC remain open.
They must not inherit any selected-profile proof status.

## Equivalence plan

Standalone Yosys synthesis and EQY equivalence are owner-approved policy `SKIP`
at the FIFO unit level. They are disabled in `config/flows.mk` and excluded
from the portable profile flow lists. Prior passing results remain historical
evidence. The retained setup below applies only if these flows are re-enabled.
Formal verification, including its internal Yosys model preparation, stays
enabled. Technology-mapped integration qualification is not waived.

The retained EQY setup compares RTL with each profile's actual Yosys-generated
netlist. Both sides flatten the common primitive hierarchy, map storage to
flops, and use `clk2fflogic` to model independent clock edges and
asynchronous reset explicitly. The control relation is grouped to avoid invalid
independent cuts through binary/Gray aliases and optimized memory read cones.
Next-binary aliases are not name-based match points because synthesis can discard
unused bits after counter reuse. Pointer state and all live consumers, including
Gray state, flags, levels, and read data, remain checked.
Storage words are checked in separate partitions for scalable execution.
The SAT strategy performs induction with maximum depth eight, not merely a
bounded output comparison.

When run, this establishes generic synthesis preservation, not target SRAM
suitability or technology-mapped synchronizer preservation.

Simulation and the retained generic synthesis setup read `dff` and `counter`
through the FIFO RTL filelist. Icarus campaigns use that same filelist.
Formal stages the exact common sources and flattens their hierarchy before
proof/cover. FIFO checks remain
independent of primitive internals and validate their integrated behavior.

## Coverage plan

HDL coverpoints are separate in `verif/coverage/`. The normal simulator, PyUVM,
and formal elaborate that layer independently from the assertion checker. Native
line/branch/toggle/user coverage is retained separately by the shared normal and
PyUVM simulation adapters. Python scenario counters are in a different JSON file.

`config/coverage-policy.json` proposes 90% line, branch, and toggle and 100%
named user bins. The quantitative qualification adapter is disabled until the
policy and all exclusions are reviewed for this dual-clock IP. That is an open
release item, not an accepted coverage waiver. PyUVM's scenario-hit requirements
are not a substitute for that quantitative policy.

The [HDL coverage model](coverage-model.md) maps all twelve issue coverage items
to twenty native cross families: clock/occupancy, activity/status, address pairs,
wrap/remote-phase, both threshold transitions, stall/level, reset/skew/stoppage,
init/first-transfer, synchronizer depth/ratio and every stage/bit/direction.
Both testbenches execute the same HDL groups. The separate integrity collector
requires every elaborated native bin and preserves zero hits. Scenario counters
and the five basic HDL points alone cannot satisfy this model.

The pinned shared quantitative parser does not read native `covergroup` metrics.
`cross-coverage.json` therefore records integrity as VALID/INVALID, with
qualification and vacuity explicitly NOT_RUN. Its all-zero control deliberately
demonstrates that VALID does not imply coverage PASS. Missing-bin controls prove
artifact integrity, not enforcement of the disabled quantitative thresholds.

Remaining closure includes shared-parser support, legal-bin/profile-specific
exclusion review, stimulus for uncovered combinations, every released
synchronizer depth, antecedent vacuity review, broader release-envelope formal
coverage, and a deficient-coverage threshold failure control. The separate
selected-profile formal matrix includes runtime-reset covers and checked
wrap-phase invariants but does not waive native bins.

## Negative and four-state plan

Shared declarative campaigns in `config/qualification-campaigns.json` run by
default through `open-negative`, `open-four-state` and `open-source` for the
`minimum` and `nominal` profiles. The negative campaign contains 24 cases:
three passing controls, seven invalid-parameter cases, output corruption,
twelve actual RTL-state faults and one PyUVM producer-offer fault. Tool failures,
fixture watchdogs and escaped-fault sentinels cannot count as detected faults.

The seven invalid-parameter cases expect successful Icarus compilation, then
a nonzero `vvp` exit with `async_fifo: invalid parameters` at time zero in
`g_invalid_parameters`. Their classification is `expected_assertion_failure`,
not an elaboration failure. The issue's stricter timing wording must be amended
to the proposed [before-execution policy](release-scope.md#invalid-parameter-rejection)
before specification closure. The existing qualification-control script also
checks each case's actual diagnostic and rejects a late fatal, missing time,
wrong diagnostic, successful illegal run and missing simulator. These controls
exercise the shared classifier, not a duplicate campaign implementation.

The Icarus payload control uses a fixed 8-bit, depth-four, two-stage fixture.
Eight patterns cover all X, all Z, four rotations of mixed 0/1/X/Z bits, a
single X among zeros and a single Z among ones. Twenty-four queued records
exercise six fill/drain bursts and pointer wraps. Every pattern must pass three
times. Each head is stalled for four reader falling edges and compared using
case equality, while flags, levels and initialization remain known.

The four-state campaign contains 32 cases: sixteen X/Z injections and sixteen
separately compiled disabled-monitor controls. Targets are `i_w_rstb`,
`i_r_rstb`, `i_w_valid`, `i_r_ready`, `r_gray_final`, `w_gray_final`,
`r_up_final` and `w_up_final`. Final-stage deposits occur on the destination
falling edge and must reach the actual checker input before they are credited.
The enabled monitor samples the unknown at the next active edge, before the
stage's nonblocking overwrite. The runner requires a nonzero result and the
named `UNKNOWN_SYNCHRONIZER_DETECTED` or `UNKNOWN_CONTROL_DETECTED` diagnostic.
Clock X/Z and analog metastability are outside this campaign.

`async_fifo_fault_tb` uses the unchanged RTL and bound behavioral SVA with a
fixed minimum-profile 1-bit, depth-two, two-stage configuration. The same compiled
binary must first deliver four records without a fault. It then forces actual
RTL registers or memory words in twelve independent runs:

| Faults | Mutation and required detector |
| --- | --- |
| `write_pointer_stage0`, `write_pointer_final` | Hold the write-domain synchronized read pointer at zero. After accepted records are read, the bounded public-port check must report missing write capacity. |
| `read_pointer_stage0`, `read_pointer_final` | Hold the read-domain synchronized write pointer at zero. The bounded public-port check must report missing read visibility. |
| `write_up_stage0`, `write_up_final`, `read_up_stage0`, `read_up_final` | Hold the receiving domain's peer-up stage low before startup. The bounded initialization check must fail while both clocks run. |
| `full_flag`, `empty_flag` | Force the corresponding registered flag low in its asserted state. The named `write_full_prediction` or `read_empty_prediction` SVA must fail. |
| `memory_hold` | Flip a real idle non-head word. `g_storage[1].storage_hold` must fail. |
| `memory_write` | Hold real word zero at zero while a one is accepted for it. `g_storage[0].storage_write` must fail. |

Every negative run must emit its injection marker followed by its specific
detector. The bounded synchronizer checks apply only to this fixture's ideal,
continuously running clocks and coordinated release. They are not general
fairness, analog latency or MTBF claims. The outer `nominal` campaign repeats
these fixed fixtures, not nominal-width/depth fault qualification. Other
polarities, transient faults, intermediate stages at larger depths, memory
addresses and parameter combinations remain open.

`bash .github/scripts/check-assertion-controls.sh` additionally runs the normal
minimum regression as a positive baseline and four focused observation-fault
controls. Each must hit its named storage-hold, invalid-output-hold, init
prerequisite, or stopped-clock asynchronous reset assertion. These controls
reuse the existing simulation adapter and remain separate from the Icarus
declarative campaign. Their scope and evidence layout are in the assertion
inventory. CI enables them in the native minimum job and container job.

The automated `test_async_fifo_assertion_control.py` intentionally corrupts a valid
producer offer held by a full FIFO. It must fail specifically in the shared
`async_fifo_sva.sv` `input_hold` assertion. No Python queue comparison should
be the first detector because the corrupt offer has not been accepted.
The declarative negative campaign first runs the full `AsyncFifoTest` as its
passing PyUVM control, then selects this fault module in separate output roots.
`run-pyuvm-control.sh` invokes the unchanged shared adapter and exposes its raw
simulation log to the campaign diagnostic matcher. It does not duplicate the
simulator backend or classify an escaped fault as a detected assertion.
The raw adapter tree is kept under the case work root. Compact evidence is
archived under the case report root's `reports/raw-pyuvm/` directory, retaining
the simulator result as `raw-status.txt` rather than a positive gate status.
Nested controls explicitly select `minimum` and clear inherited outer-profile
disabled-flow policy so that applicability is recomputed for the fixture.
Manual debugging is still available with isolated output roots:

```sh
make PROFILE=minimum DISABLED_FLOWS= open-pyuvm \
  PYUVM_TEST_MODULE=test_async_fifo_assertion_control \
  REPORT_DIR="$PWD/reports/pyuvm_assertion_control" \
  WORK_DIR="$PWD/work/pyuvm_assertion_control"
```

An expected nonzero Make result must be accompanied by the named HDL assertion
diagnostic in `reports/pyuvm_assertion_control/minimum/pyuvm_open_source/simulation.log`.
`PYUVM_ASSERTION_ESCAPED`, missing tools, or build errors are not successful
detection. The raw adapter status remains FAIL, while the campaign case records
PASS only for the expected, attributable assertion failure. The ordinary
positive PyUVM regression remains separate and must pass.

## Reproducibility

```sh
make all-profiles PROFILE_JOBS=2 PROFILE_TARGET=open-source
make PROFILE=minimum open-formal open-negative open-four-state
make PROFILE=nominal open-pyuvm
./.github/scripts/check-pyuvm-evidence.sh reports/nominal/pyuvm_open_source
```

Retain per-profile logs and work products. GitHub Actions runs portable profiles,
not commercial signoff. Do not assign ASIC release approval from portable PASS.
