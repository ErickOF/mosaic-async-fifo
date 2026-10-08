# Assertion inventory

[Return to the documentation index](README.md).

This inventory follows the nineteen required-assertion items in
[issue #1](https://github.com/ErickOF/mosaic-async-fifo/issues/1).
An implemented behavioral check is not structural CDC/RDC or ASIC signoff.
Systematic antecedent/vacuity review and broader fault coverage remain open.

## Shared implementation

The normal SystemVerilog testbench and PyUVM compile
`filelists/properties.f` and `filelists/assertions.f`. The bind wrapper connects
the actual FIFO state and memory to the passive `async_fifo_sim_checker` array
adapter, which instantiates `async_fifo_sva` as `u_behavior`. The adapter only
packs storage observations and contains no duplicated checking logic.

Formal instantiates `async_fifo_sva` directly through `MOSAIC_FORMAL`. Its packed
observation wiring is excluded from ordinary RTL synthesis. The Yosys branch
uses procedural assertions and the same prediction/reset predicates as SVA.
Expected next pointers, flags, and levels are derived from canonical public
handshakes and final synchronized pointers, not DUT next-state expressions.

Coverage remains a separate HDL layer. Python's queue and the formal reference
memory remain independent of observed DUT pointers and storage.
The [native cross model](coverage-model.md) is not antecedent/nonvacuity evidence.
Two formal-only wrap-phase reachability assertions reside in the state coverage
observer; they justify each selected formal target set without assuming those
phase relations or waiving simulation bins.

## Requirement mapping

| # | Issue requirement | Checker or analysis | Scope and remaining evidence |
| --- | --- | --- | --- |
| 1 | Producer holds valid and data while stalled | `input_hold` | SVA in initialized SV/PyUVM epochs. Formal assumes the external producer obligation in that scope. Reset cancellation ends the offer. Draft AFIFO-CHANNEL-V1 preserves the pre-initialization hold obligation, which is not closed by the initialized checker. Contract approval and independent pre-initialization review remain open. |
| 2 | Consumer sees stable valid and data while stalled | `output_hold` | SVA and formal procedural equivalent. Cancellation ends the obligation. |
| 3 | No push while full or uninitialized | `write_handshake`, `write_status`, `write_permission` | Behavioral checks include the actual internal push and public ready equation. |
| 4 | No pop while empty or uninitialized | `read_handshake`, `read_status`, `read_permission` | Behavioral checks include the actual internal pop and public valid equation. |
| 5 | Binary pointers advance only on local handshake | `write_pointer`, `read_pointer` | Exact wrapping increment or hold on their respective clocks. Physical clock ownership still needs structural review. |
| 6 | Gray source changes at most one bit | `write_gray`, `read_gray`, `write_gray_encoding`, `read_gray_encoding` | Checks both source transitions and binary-to-Gray correspondence, not analog destination sampling. |
| 7 | Only final synchronizer stages feed functional logic | Structural CDC and mapped fanout audit | **Pending.** Prediction checks observe final stages but cannot exclude hidden intermediate-stage fanout. |
| 8 | Full is generated and registered in write domain | `write_full_prediction`, `write_status` | Checks local-edge prediction against the final synchronized read pointer. Exclusive clock ownership and registration require structural evidence. |
| 9 | Empty is generated and registered in read domain | `read_empty_prediction`, `read_status` | Checks local-edge prediction against the final synchronized write pointer. Exclusive clock ownership and registration require structural evidence. |
| 10 | Initialized levels remain in range | `write_level_range`, `read_level_range`, `write_level_prediction`, `read_level_prediction` | Exact local estimate equations plus range bounds. Independent queue/reference checks establish conservatism in their tested/proven scope. |
| 11 | Storage writes require push | `g_storage[*].storage_write`, `g_storage[*].storage_hold`, `write_handshake` | Each actual word must commit accepted payload or hold, including through reset. The RTL directly uses push as write enable. Structural port/write-enable ownership remains a mapping review. |
| 12 | A live storage location cannot be overwritten | `write_live_slot`, `read_live_slot`, `g_storage[*].visible_head` | Pointer distance prohibits push at full live occupancy, pop at zero occupancy, and mismatched visible head. Flag prediction also enforces conservative synchronized ownership. Canceled epochs are excluded. |
| 13 | Output changes only for qualified head capture or reset | `read_load_qualification`, `output_capture`, `output_idle_hold`, `g_storage[*].visible_head` | Valid-load selection, exact captured payload, and hold even while invalid. Observations are tied to real storage. |
| 14 | Reset forces safe interfaces | `write_async_reset`, `read_async_reset`, `write_reset_sample`, `read_reset_sample` | Pointers, final synchronizers, local up/seen state, levels, safe flags, init/ready/valid, and read data are checked. Simulation uses a settled precision tick, formal uses a settled global observation even without a local edge. Intermediate-stage reset structure and recovery/removal need CDC/RDC/STA evidence. |
| 15 | Init requires synchronized peer-up | `write_init_prerequisites`, `read_init_prerequisites` | A sampled init requires own reset released, own domain up, and final synchronized peer-up. |
| 16 | One-sided reset requires coordinated recovery | `write_peer_shutdown`, `read_peer_shutdown`, `write_shutdown_sticky`, `read_shutdown_sticky`, `write_shutdown_blocks`, `read_shutdown_blocks`, `write_seen_sticky`, `read_seen_sticky` | Observed peer-down makes local up fall. It stays down and blocks handshakes until own reset. SV/PyUVM exercise both directions. Separate runtime targets check the documented reset-visibility contract and require shutdown/recovery witnesses. |
| 17 | Payload has no direct control fanout | Structural cone-of-influence/CDC audit | **Pending.** X/Z transport/control tests complement, but do not replace, a structural fanout audit. |
| 18 | No combinational interdomain path | Structural CDC and path audit | **Pending.** Behavioral sampling cannot establish the absence of a hidden path. Approved storage crossings need separate bundled-data timing treatment. |
| 19 | Local handshake controls are known at active edges | `write_controls_known`, `read_controls_known`, `write_synchronizers_known`, `read_synchronizers_known` | Public controls include almost flags and levels. Final Gray and domain-up stages are checked directly. Shared predicates run as Icarus immediate monitors with paired disabled-monitor X/Z controls. Two-state engines cannot establish X/Z detection. |

`write_threshold` and `read_threshold` additionally check both almost-status
equations for each profile's thresholds. No cross-clock liveness assertion is
claimed. Such proofs need explicit clock fairness, reset, and endpoint-progress
assumptions.

## Sampling and reset scope

The storage checker samples the complete actual array and accepted write tuple
once per write edge. Each generated word compares its own slice of that history.
These checks are never disabled by reset because payload memory is unreset.
Storage may change only by the previous accepted write, even if reset intervenes.

Local SVA history-valid bits clear asynchronously. The first post-reset sample
cannot inherit an outstanding obligation from before a stopped-clock reset.
Subsequent samples check ordinary pointer, status, output, and shutdown history.
Async reset monitors wait `1ps`, one checker time-precision tick, for nonblocking
updates to settle before evaluating the shared reset predicate. This is digital
testbench scheduling, not a reset pulse-width or hardware timing specification.

Live ownership checks require both raw resets released and both domains up with
the peer previously observed. This is observation-only verification logic, not
a hardware reset or binary-pointer crossing. A legal unilateral reset cancels
the live epoch immediately. Peer-down propagation and sticky local shutdown are
checked separately. Pulses too short to be observed by the coordinated reset
architecture remain illegal integration behavior, not proven recovery cases.

The minimum profile formal harness has coordinated startup reset, then
independently advancing or stopped clocks. Its safety proof includes the new
storage, output, prediction, and initialization checks. Shutdown assertions are
present but their runtime-reset antecedents are not reached by that harness.
The separate formal matrix adds runtime-reset and bounded variable-capture
models with explicit shutdown, cancellation, recovery and delay witnesses.
See [formal model](formal-model.md) for per-target evidence and assumptions.
These results do not upgrade the minimum startup proof into a wider-parameter,
arbitrary-delay, analog-metastability or ASIC timing claim. Systematic assertion
non-vacuity review remains open.

The `MOSAIC_FOUR_STATE` branch runs only known-control and final-synchronizer
immediate monitors. A final-stage X/Z check runs before public-control checks
and reports the receiving domain directly. Each disabled-monitor control proves
the deposit reached the checker input, then permits the injection to escape.
It does not execute concurrent SVA or the new storage/output history checks.
Full four-state SVA requires a qualified SVA-capable simulator.

## Focused failure controls

```sh
bash .github/scripts/check-assertion-controls.sh
```

The existing mosaic-flow simulation adapter compiles the minimum-profile
`async_fifo_assertion_control_tb`. Without a fault it runs the complete normal
regression as the positive control. The wrapper then supports four isolated
observation faults that must fail specifically in `storage_hold`,
`output_idle_hold`, `write_init_prerequisites`, or `write_async_reset`.
The reset case stops the write clock before asserting reset, so a later clock
edge cannot be the detector. These are checker failure controls, not physical
memory or synchronizer fault qualification. The actual FIFO and independent
scoreboard are unchanged by the corrupted checker observations.

Reports are isolated in `reports/assertion_controls/minimum/verilator_sim/`.
The baseline `status.txt` records PASS independently of the expected failing
logs. `controls-status.txt` records PASS only when all four faults reach their
injection marker and named HDL assertion without escaping. A successful run,
wrong assertion, build failure, or escaped fault fails the control script.
GitHub Actions runs these controls for the native minimum job and container.
Optional `REPORT_DIR` and `WORK_DIR` select separate output roots.

The declarative negative campaign additionally uses `async_fifo_fault_tb` to
force actual RTL state, not checker observations. Four pointer and four
domain-up stage faults use fixture-bounded public-port progress checks with
both ideal clocks running. Full/empty mutations hit the named flag-prediction
SVA. Idle storage corruption and suppression of an accepted write hit the
named per-word `storage_hold` and `storage_write` SVA. The passing no-fault
binary and all twelve mutated runs use the fixed minimum configuration.

The PyUVM producer-offer fault now runs automatically in the same negative
campaign after a passing full PyUVM control. It must reach the injection marker
and shared `input_hold` SVA. Its raw adapter FAIL is retained independently of
the campaign's expected-failure PASS. Counts, fixture scope and debugging
invocations are documented in the [verification plan](verification-plan.md).
None of these sets closes the complete fault matrix, antecedent-vacuity review,
or mandatory structural signoff.
