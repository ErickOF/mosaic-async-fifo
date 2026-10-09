# HDL coverage model

[Return to the documentation index](README.md).

This model implements the twelve required coverage items from
[issue #1](https://github.com/ErickOF/mosaic-async-fifo/issues/1).
Implementation and artifact integrity do not establish quantitative coverage
closure, approved exclusions, assertion nonvacuity, or ASIC qualification.

## Reuse and observation

`filelists/coverage.f` compiles the independent coverage layer for ordinary
SystemVerilog simulation and PyUVM. `async_fifo_coverage_bind` attaches the
passive `async_fifo_sim_coverage` adapter to the actual FIFO. That adapter packs
the actual Gray/domain-up synchronizer arrays and instantiates:

- `async_fifo_coverage`: state/history observations and native covergroups from
  `async_fifo_state_covergroups.svh`.
- `async_fifo_timing_coverage`: simulation-only clock and reset/init observations.

PyUVM does not call these groups from Python. They execute inside the simulator
for the same DUT driven by either testbench. Python scenario hits and independent
queue checking remain separate. No reference-queue occupancy or requested test
mode is credited as an HDL cross hit.

Formal instantiates the same state observer through synthesis-excluded
`MOSAIC_FORMAL` wiring. Its Yosys branch uses individual procedural covers and
does not compile covergroups or real-time delay observers. Ordinary functional
RTL and the pinned common/flow dependencies are unchanged.

## Requirement mapping

| # | Required coverage | Native cross and sampling |
| --- | --- | --- |
| 1 | Clock relationship versus occupancy boundary | `write_clock_cg` / `read_clock_cg.clock_occupancy`: five observed clock relations by empty/partial/full actual pointer distance, sampled at operational local edges. |
| 2 | Push/pop activity versus full and empty | `write_activity_cg` / `read_activity_cg.activity_status`: actual accepted local transfer by both current status flags. Each port retains all eight combinations. |
| 3 | Pointer wrap versus synchronized remote phase | `write_wrap_cg` / `read_wrap_cg.wrap_remote_phase`: the new local binary MSB after a wrap by the incoming final Gray MSB. Both phase values are retained. |
| 4 | Every write address versus every read address | `write_address_cg` / `read_address_cg.address_pair`: all `DEPTH * DEPTH` current address pairs, credited only on an actual accepted transfer in that port. The remote address snapshot is not a simultaneous remote acceptance. |
| 5 | Almost-full entry and exit | `write_threshold_cg.threshold_transition`: flag entry/exit by exact local write estimate. Both adjacent samples must be initialized. |
| 6 | Almost-empty entry and exit | `read_threshold_cg.threshold_transition`: flag entry/exit by exact local read estimate. Remote-pointer advances can skip levels on exit. |
| 7 | Source stall versus write level | `write_stall_cg.stall_level`: offered-valid/not-ready by exact initialized local estimate, including non-stall samples. |
| 8 | Destination stall versus read level | `read_stall_cg.stall_level`: valid/not-ready by exact initialized local estimate, including non-stall samples. |
| 9 | Reset versus empty/partial/full | `reset_cg.reset_state_skew_stop`: pre-reset actual pointer distance, with a separate uninitialized category. |
| 10 | Reset skew versus clock stoppage | The same reset cross adds first assertion order and actual write/read edge inactivity during a bounded observation window. Both-clock inactivity is represented. |
| 11 | Init order versus first post-reset transfer | `init_cg.init_first_transfer`: actual init-done assertion order by first accepted transfer direction. Exact-time ties are distinct bins. |
| 12 | Synchronizer depth versus frequency ratio | Each clock group's `depth_ratio`: the elaborated `SYNC_STAGES` by all five clock relations. Depth changes require separate profile evidence. |

Additionally, `read_gray_cg` and `write_gray_cg.stage_bit_direction` observe each
incoming synchronizer stage, pointer bit, and transition direction.
`read_up_cg` and `write_up_cg.stage_direction` observe both domain-up transition
directions at every stage. Local pointer-phase coverpoints and the original five
user counters remain supplementary, not replacements for these crosses.

There are twenty cross families: ten port, four synchronizer, four clock, one
reset, and one initialization cross. Every native bin has its own counter.

## Sampling semantics

State groups sample pre-NBA at local rising edges. Previous-sample histories
are updated nonblocking, and local reset clears history validity. A wrap is
observed at the first local rising sample after the pointer MSB changes. Its
phase is the new phase, not a prediction of the offered next pointer. Threshold
events exclude initial flag values and reset transitions. Ordinary non-transition
cycles do not call the threshold sampler.
Each state group has one event guard around its `sample()` call. A coverpoint
guard alone does not prevent a cross from counting unqualified cycles, and
cross `iff` is unsupported by this simulator. Ten independent single HDL event
counters validate exact count conservation for the state crosses. These sample
controls are not systematic SVA antecedent/nonvacuity evidence.
All twenty crosses additionally conserve counts against a component coverpoint.

Clock classification uses the latest completed falling-edge periods. The five
relations are write-faster, equal completed periods, read-faster, write-inactive,
and read-inactive. Inactivity means the last falling edge is older than twice
that clock's last measured period. Unknown startup history is not credited.
These are digital observations, not a nominal-rate or jitter specification.
A restart interval can include stopped time; profile/trace review is still needed.

Reset occupancy and first assertion order are captured on the first raw reset
assertion in an epoch, before pointer-reset NBA updates. The asynchronous
observer waits one precision tick, then counts actual rising edges over twice
the larger last measured period, with a minimum 32 ns window. No edges means
inactivity in that window, not proof of an indefinitely stopped clock. The other
reset assertion does not create a second sample for the same canceled epoch.

Initialization order is based on actual init-done outputs, not reset-release
order. First accepted-transfer timestamps are consumed at a falling edge after
rising-edge updates settle. A fresh empty FIFO normally cannot accept a read
before its first write; read-first/tie bins stay visible pending reachability
review rather than being silently removed.

## Native bin integrity

The pinned simulator merges counters from generated `cover property` loops.
Native covergroups over narrow bit vectors preserve individual automatic bins.
Distinct write/read group types prevent aggregation of port instances. The
literal automatic-bin limit is 65536; the five representative profiles are
validated, not every larger legal configuration.

Native automatic ranges include padding: levels above `DEPTH`, and unused
indices when stage/bit counts are not powers of two. Illegal accepted-push/full,
accepted-pop/empty, and some stall/threshold/wrap combinations also remain zero.
The collector preserves these identities. None is automatically waived or
excluded from a release percentage. Exact legal-bin policy and profile-specific
unreachability reviews remain open. Candidate COV-001 only scopes generated
simulator warnings; it is not a coverage exclusion.

Run after a positive simulation:

```sh
python3 .github/scripts/check-cross-coverage.py reports/minimum/verilator_sim
./.github/scripts/check-pyuvm-evidence.sh reports/minimum/pyuvm_open_source
python3 .github/scripts/test-cross-coverage.py reports/minimum/verilator_sim
```

`cross-coverage.json` records all native bin identities/hits, effective profile
parameters, source names, native database SHA-256, qualified state-sample counts,
and empty applied-waiver list.
Missing/duplicate bins, wrong depth shape, extra unqualified state-cross samples,
or non-PASS positive simulation fail
integrity. Zero-hit bins remain present. `artifact_status=VALID` means only that
the expected bin identities exist. Even an all-zero fixture remains VALID with
`coverage_qualification=NOT_RUN` and `assertion_vacuity=NOT_RUN`.

The eight isolated artifact tests verify this boundary, including rejection of
evidence containing only the original five HDL counters. Neither databases,
testbench results, nor depth profiles are merged. Native and container CI checks
run the collector for both positive simulators and retain the JSON reports.

## Formal scope and open qualification

The minimum startup-only formal model covers legal address/activity/stall and
threshold combinations, both pointer phases, reachable wrap-phase pairs, and
all Gray-stage transitions. Domain-up rising transitions are covered; runtime
reset/falling transitions use the separate runtime-reset harness. The
[formal matrix](formal-model.md) adds depth four, threshold endpoints, three
stages, runtime cancellation and independently delayed coherent captures.
Runtime targets require all stage/domain-up falling transitions and explicit
reset/stop/shutdown/recovery witnesses. Each exact model has separate proof and
cover acceptance; none inherits the minimum result.

At an observed write wrap, local phase differs from synchronized read phase;
at an observed read wrap, local phase equals synchronized write phase. Two
additional assertions check these invariants without assuming them. Complete
profile-specific complete proofs check these assertions, so each corresponding
formal cover set includes those reachable pairs. This is not a simulation-bin
waiver or a claim about every parameter or capture-delay model. All four native
wrap pairs remain recorded.

The MF20260910V1 quantitative parser recognizes `user` counters but not native
`covergroup` records. It cannot qualify these crosses. Do not enable the old
five-counter policy and call cross coverage closed. Shared-parser support,
reviewed legal-bin/clock-profile exclusions, uncovered-bin stimulus, quantitative
line/branch/toggle/cross thresholds and a deficient-threshold failure control
are pending. Systematic SVA antecedent/nonvacuity review remains independently
open. Selected shutdown and delayed-capture witnesses do not substitute for a
systematic per-assertion antecedent/nonvacuity analysis.
