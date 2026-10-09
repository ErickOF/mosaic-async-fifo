# Formal verification model

## Targets and scope

`config/parameter-profiles.json` retains the original five portable profiles.
Only its `minimum` profile enables formal. The independent
`config/formal-profiles.json` adds the following formal-only targets. Parameters
are applied to `async_fifo_formal`, not to production simulation tops.

| Profile | Data bits / depth / stages | Almost full / empty | Reset | Capture |
| --- | --- | --- | --- | --- |
| depth4 | 1 / 4 / 2 | 3 / 1 | Startup | Exact |
| depth4_edges | 2 / 4 / 2 | 4 / 3 | Startup | Exact |
| depth2_three_stages | 1 / 2 / 3 | 1 / 0 | Startup | Exact |
| reset_depth2 | 1 / 2 / 2 | 1 / 0 | Runtime | Exact |
| reset_depth4 | 1 / 4 / 2 | 3 / 1 | Runtime | Exact |
| reset_three_stages | 1 / 2 / 3 | 1 / 0 | Runtime | Exact |
| delayed_reset_depth2 | 1 / 2 / 2 | 1 / 0 | Runtime | Variable |
| delayed_reset_depth4 | 1 / 4 / 2 | 3 / 1 | Runtime | Variable |
| delayed_reset_three_stages | 1 / 2 / 3 | 1 / 0 | Runtime | Variable |

Depth four adds address and wrap state beyond the minimum. Two payload bits
add unequal-bit payload patterns and the legal threshold endpoints. Three
stages test a longer pipeline independently of queue depth. Runtime reset and
variable capture each repeat the depth-two, depth-four, and three-stage cases.
These are justified representative targets, not a proof of every legal width,
depth, threshold or synchronizer-stage combination. In particular, the
32/64/128-bit portable profiles do not inherit these proof results.

## Environment obligations

- Clocks toggle during fixed startup, then each clock independently toggles or
  holds on any symbolic global step. Either can stop forever. Simultaneous
  edges are allowed. This is a discrete two-state edge model, not real-time
  clock-ratio, phase, jitter, timing or analog analysis.
- Payload, source valid and consumer readiness are symbolic. An initialized
  producer must hold its offered payload and valid while stalled within an
  active reference epoch. This endpoint obligation is assumed, not proved.
- Initial raw resets overlap. In runtime profiles, either raw reset may assert
  at any global step, independently of clocks and occupancy, and may stay low.
  Release occurs only on a local falling edge, never a local rising edge.
- A unilateral reset cannot release until it has stayed low for
  `SYNC_STAGES + VARIABLE_CAPTURE + 1` peer rising edges, or while the peer
  raw reset is also low. The last edge accounts for sticky peer shutdown.
  This explicitly encodes reset visibility. It does not prove a pulse reaches
  a stopped peer: the reset must remain asserted or the peer must also reset.
- Recovery requires overlapping raw resets. Cancellation starts on either raw
  assertion, before the synchronized peer necessarily blocks its interface.
  The system must discard traffic in this propagation window.

No assumption forces internal DUT pointers, flags, memory, domain-up values or
ready/valid outputs. The producer assumption is qualified by observed public
initialization and backpressure. Reset requests are otherwise unconstrained,
including requests during initialization and repeated cancellation. There is
no clock, reset-release or endpoint-progress fairness assumption, hence no
unconditional eventual-delivery/recovery proof. The integration owner still
needs to review and approve this reset/offer contract for overconstraint.

## Independent reference and shared checks

The reference memory and addresses follow accepted public transactions. Either
raw reset asynchronously clears both reference addresses and source-offer
history, even when a local clock is stopped. Stored payload bits are not reset.
A reference epoch is armed by overlapping raw resets and opens when both are
released. It does not wait for both `init_done` outputs: an accepted write may
legitimately precede read initialization. A one-sided reset invalidates the
epoch until another overlapping reset. Old data is not considered delivered
after cancellation, and fresh accepted writes must precede every valid head.

Within each active epoch the independent queue checks ordering at every valid
head, occupancy bounds, no overwrite/underflow, and conservative local levels.
The shared `async_fifo_sva` separately checks actual storage write/hold behavior,
pointer advancement, Gray encoding/steps, flag and level prediction, thresholds,
initialization permissions, output capture/hold and sticky shutdown. Its
predictions are not replaced by the reference queue. Storage checks remain
active across resets because production memory is unreset.

Local temporal history is invalidated asynchronously. Formal asynchronous-reset
state checks use a settled global observation while raw reset remains low and
therefore also work when the local clock is stopped. Runtime harness checks
prove peer interface shutdown after the stated number of actual peer edges.
They do not assume the peer's outputs to obtain that result.

## Variable propagation abstraction

`MOSAIC_FORMAL` permits the harness to select a first-stage capture replacement
through `FORMAL_VARIABLE_CAPTURE`. These formal-only parameters and the helper
module are absent from normal production elaboration. Production still has
exactly `SYNC_STAGES` attributed registers per crossing and uses its original
capture logic. The generate wrapper is not a new hardware pipeline stage.

Each of the two Gray pointers and two domain-up crossings independently chooses
whether to capture its coherent source word at the first destination edge or
retain the previous first-stage value for one extra destination edge. A second
consecutive deferral is prohibited by the model's transition logic. Remaining
stages are the exact RTL pipeline. A stable source therefore reaches the final
stage in `SYNC_STAGES` or `SYNC_STAGES + 1` destination edges. New source changes
may be skipped, as with a fast source and slower destination.

This overapproximates coherent digital capture schedules only. It does not
model bit tearing, arbitrary delay, analog metastability, X/Z values, MTBF,
recovery/removal, Gray-bus skew or implementation constraints. Each crossing
has two explicit cover witnesses: a genuinely stale deferred value and forced
capture despite another defer request. Passing nominal-only paths cannot close
the delayed profile's reachability task.

## Proof and reachability acceptance

The existing mosaic-flow SymbiYosys adapter is reused without modification.
ABC PDR performs a complete safety proof; its `depth 48` setting is not a
48-step bounded PASS. Cover mode is separate, uses SMTBMC/Bitwuzla and a bound
of 128 global steps. Proof has a 1200-second timeout and cover mode retains its
600-second timeout. These are wall-clock resource budgets, not proof bounds.
A timeout, UNKNOWN, unreached cover, missing tool or missing trace fails the
profile, not a waiver.

The shared observer covers legal address/activity/stall/level/threshold/phase
targets and every Gray/domain-up stage transition. Checked wrap invariants,
not assumptions, scope the reachable formal wrap targets. Runtime profiles
also require empty/partial/full and stalled-head cancellation, unilateral and
joint reset, reset with either/both clocks held, each peer-shutdown direction,
peer-down observations after raw release, new-epoch write/read recovery and repeated
cancellation/recovery. These witnesses establish reachability of selected
obligations, not exhaustive assertion antecedent non-vacuity.

`check-formal-evidence.py` checks the exact profile, applied parameters,
complete-proof engine, current staged source hashes, task PASS status and every
cover's structured SQLite status and trace. It records profile-specific
`formal-evidence.json`, including each source location, witness step and trace.
Results are not merged across models or profiles. Full vacuity, broader
parameter proofs, physical CDC/RDC and ASIC signoff remain independent gates.

Eight disposable artifact controls exercise a valid positive fixture and
reject combined SKIP, wrong parameters, a missing proof, an unreached cover,
a missing required trace, stale checker source and an unqualified bounded
engine. These qualify evidence integrity, not RTL fault detection or assertion
vacuity. The release checklist keeps those distinctions explicit.

## Run

From the repository root:

```sh
make PARAMETER_PROFILE_MANIFEST=config/formal-profiles.json profile-manifest-check
make PARAMETER_PROFILE_MANIFEST=config/formal-profiles.json \
    PROFILE=reset_depth4 REPORT_DIR="$PWD/reports/formal" \
    WORK_DIR="$PWD/work/formal" open-formal
python3 .github/scripts/check-formal-evidence.py --profile reset_depth4 \
    --reports reports/formal/reset_depth4 --work work/formal/reset_depth4

make PARAMETER_PROFILE_MANIFEST=config/formal-profiles.json \
    all-profiles PROFILE_JOBS=2 PROFILE_TARGET=open-formal \
    REPORT_DIR="$PWD/reports/formal" WORK_DIR="$PWD/work/formal"
while IFS= read -r profile; do
    python3 .github/scripts/check-formal-evidence.py --profile "$profile" \
        --reports "reports/formal/$profile" --work "work/formal/$profile"
done < <(make --silent PARAMETER_PROFILE_MANIFEST=config/formal-profiles.json profile-list)
python3 .github/scripts/test-formal-evidence.py --profile delayed_reset_depth2 \
    --reports reports/formal/delayed_reset_depth2 --work work/formal/delayed_reset_depth2
```

GitHub Actions has a separate, bounded-concurrency formal matrix and retains
proof sources, property databases and cover traces as artifacts. Hosted CI
execution is distinct from local native/container evidence.

Native formal jobs keep two concurrent, separately hosted profiles and allow
40 minutes per job for tool setup, the 20-minute proof budget, the 10-minute
cover budget and evidence retention. The container job allows 75 minutes for
the portable sweep, assertion controls and the formal sweep. Portable profiles
still run with `PROFILE_JOBS=2`, but the formal-only container sweep uses
`PROFILE_JOBS=1` so its PDR and SMT workloads do not compete with another formal
profile on the same runner. Every formal profile and evidence control remains
required. This scheduling/resource change does not alter the model, assumptions,
assertions, qualified engine or cover bound, and does not turn timeout into PASS.
