# Interface specification

[Return to the documentation index](README.md).

## Overview

`async_fifo` transfers fixed-width opaque records between independent rising-edge
write and read clocks. Record interpretation, packet boundaries, routing, and
context semantics belong to consumers, not this FIFO.

## Parameters

| Parameter | Default | Legal values |
| --- | --- | --- |
| `DATA_WIDTH` | 32 | Positive integer |
| `DEPTH` | 8 | Power of two, at least 2 |
| `SYNC_STAGES` | 2 | Integer at least 2 |
| `ALMOST_FULL_LEVEL` | `DEPTH-1` | 1 through `DEPTH` |
| `ALMOST_EMPTY_LEVEL` | 1 | 0 through `DEPTH-1` |

Derived local parameters cannot be overridden:
`ADDR_WIDTH=$clog2(DEPTH)`, `PTR_WIDTH=ADDR_WIDTH+1`, and
`LEVEL_WIDTH=$clog2(DEPTH+1)`. The current illegal-parameter guard rejects at
simulation time zero with `$fatal` before clocked FIFO operation. In Icarus this
is a runtime assertion failure following successful compilation, not a
compilation/elaboration error. Successful compilation alone does not validate
an illegal tuple. See the proposed
[before-execution rejection policy](release-scope.md#invalid-parameter-rejection).

The [proposed first-release envelope](release-scope.md#parameter-envelope)
lists five exact tuples, not a Cartesian product of their parameter values.
Scope approval remains pending. Other legal values remain exploratory.
No ASIC configuration is released yet.

## Clocks and resets

| Signal | Domain | Contract |
| --- | --- | --- |
| `i_w_clk` | Write | Independent rising-edge clock |
| `i_r_clk` | Read | Independent rising-edge clock |
| `i_w_rstb` | Write | Active low, asynchronous assertion, externally synchronized release |
| `i_r_rstb` | Read | Active low, asynchronous assertion, externally synchronized release |

No generated clock is used. Either clock may stop indefinitely. Startup and
recovery cannot complete without enough edges in both domains. Resets must be
driven from one coordinated reset controller through two domain-local reset
synchronizers, such as the
[`reset_synchronizer`](../submodules/mosaic-common/rtl/reset_synchronizer.sv)
in the common submodule at release `MC20261005V1`. The FIFO does not synchronize
reset release internally.

## Ports

| Port | Direction | Width | Domain and meaning |
| --- | --- | --- | --- |
| `i_w_clk` | Input | 1 | Write clock |
| `i_w_rstb` | Input | 1 | Write reset |
| `i_w_valid` | Input | 1 | Write offer |
| `o_w_ready` | Output | 1 | Write acceptance enabled |
| `i_w_data` | Input | `DATA_WIDTH` | Write payload |
| `o_w_full` | Output | 1 | Registered write-domain full or reset-safe flag |
| `o_w_almost_full` | Output | 1 | Initialized and write estimate at least threshold |
| `o_w_level` | Output | `LEVEL_WIDTH` | Registered conservative write occupancy |
| `o_w_init_done` | Output | 1 | Local domain up and synchronized peer up |
| `i_r_clk` | Input | 1 | Read clock |
| `i_r_rstb` | Input | 1 | Read reset |
| `o_r_valid` | Output | 1 | Registered head is available |
| `i_r_ready` | Input | 1 | Read acceptance |
| `o_r_data` | Output | `DATA_WIDTH` | Registered read payload |
| `o_r_empty` | Output | 1 | Registered read-domain empty or reset-safe flag |
| `o_r_almost_empty` | Output | 1 | Uninitialized or read estimate at most threshold |
| `o_r_level` | Output | `LEVEL_WIDTH` | Registered conservative read occupancy |
| `o_r_init_done` | Output | 1 | Local domain up and synchronized peer up |

## Functional behavior

The proposed versioned protocol/cancellation artifact is
[`AFIFO-CHANNEL-V1`](contracts/async-fifo-channel-v1.md). It is FIFO-owned and
currently DRAFT, not supplied by MC20261005V1. Approval and publication are
tracked in the [specification decision record](release-scope.md).

A write is accepted only at a rising `i_w_clk` edge with
`i_w_valid && o_w_ready`. A read is accepted only at a rising `i_r_clk` edge
with `o_r_valid && i_r_ready`. Accepted records are delivered exactly once and
in order within an uninterrupted reset epoch.

`o_w_ready = o_w_init_done && !o_w_full`.
`o_r_valid = o_r_init_done && !o_r_empty`.

The producer holds valid and payload until acceptance or reset-epoch
cancellation. The FIFO holds valid and output data under read backpressure
until acceptance or cancellation. Unknown payload bits are transported as
payload in four-state simulation. Unknown clocks, resets, valid, or ready are
illegal, and there is no hardware error output.

Write/read pointers advance only on their own accepted transfer. Gray buses
and domain-up bits cross through independent synchronizer chains. Only the
final stage feeds functional logic. No payload control bus crosses directly.

The binary pointers use common `counter` instances with `WIDTH=PTR_WIDTH`,
`ASYNC_RESET=1`, and `SATURATE=0`. Gray pointers, domain-up bookkeeping,
full/empty flags, levels, and the read output use common `dff` banks with
asynchronous reset. These primitives are read from the pinned MC20261005V1
submodule. Generic `dff` banks do not replace the dedicated CDC chains, and
payload storage is still an unreset inferred array.

## Occupancy and thresholds

During initialized, uninterrupted operation, the registered write estimate
overestimates actual occupancy and the registered read estimate underestimates
it. Both are in `[0, DEPTH]`. They are not a coherent cross-domain count.

Almost-full is `o_w_init_done && o_w_level >= ALMOST_FULL_LEVEL`.
Almost-empty is `!o_r_init_done || o_r_level <= ALMOST_EMPTY_LEVEL`.
Never use these estimates as a substitute for ready/valid handshakes.

## Timing contract

A first available head is captured from storage into the read output register
before valid is asserted. On a pop, the next locally visible head is prefetched
on the same read edge. Consequently successive already-visible records can
pop on every read clock, without an inserted output bubble.

Cross-domain visibility depends on phase, `SYNC_STAGES`, and local registered
flag update. There is no fixed latency measured in a single shared clock.
Full deassertion is similarly delayed by read-pointer synchronization. Invalid
output data holds its previous value and is not a live memory read bus.

## Reset and recovery

Local reset clears local pointers, pointer/domain-up synchronizers, the local
up indication, registered flags and levels, and read output data. Full resets
to one, empty to one, and both levels and read output data to zero. Storage is
not reset. Traffic is disabled until both domain-up indications are observed.

A reset cancels every buffered record and outstanding offer in the epoch.
After a one-sided reset, the peer remains active until the down indication
propagates. Traffic in that window is canceled, not guaranteed delivered.
Once an already-seen peer drops, the local up indication remains low until
local reset. Merely releasing the reset side cannot safely reinitialize the
FIFO. Reset both sides before resuming traffic.

A stopped destination clock cannot observe a peer reset. Integrators must
hold coordinated resets until both domains have reset and synchronize release
after clocks restart. A short reset pulse invisible to the remote clock is
not a safe recovery protocol.

## Low-power and test behavior

The current UPF intent is one always-on supply domain at one voltage. Clock
stoppage is supported, but unilateral power loss, retention, scan bypass, and
clock/reset gating sequences are not implemented. Voltage-crossing, switchable,
or scan-enabled integrations require their own qualified DFT/UPF/CDC/RDC and
physical checks.

## Integration assumptions

- Keep each ready/valid interface local to its named clock domain.
- Preserve every synchronizer stage and colocate destination stages physically.
- Constrain Gray source-to-first-stage delay and inter-bit skew explicitly.
- Do not use broad asynchronous clock groups or false paths that mask Gray checks.
- Select and characterize dual-clock storage and its read-during-write behavior.
- Qualify reset recovery/removal, CDC/RDC recognition, MTBF, and timing at the
  selected library, voltage, frequency, temperature, and physical corner.
- Approve and publish the versioned ready-valid/cancellation artifact before
  release, and record its immutable revision and content hash.

The architecture follows the synchronized Gray-pointer approach described by
[Cummings, SNUG 2002](https://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf).
The registered prefetch and reset handshake are specified explicitly above.
