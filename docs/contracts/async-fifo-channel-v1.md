# AFIFO-CHANNEL-V1

## Identity and status

- Proposed publisher: `mosaic-async-fifo`.
- Artifact version: `AFIFO-CHANNEL-V1`.
- Scope: `async_fifo` opaque-record ready-valid behavior and destructive reset
  cancellation, extracted from issue #1 and the current interface.
- Status: DRAFT, pending maintainer approval and immutable publication.
- RTL dependency: `mosaic-common` MC20261005V1 at
  `6eff6d3d8e43265ca8eff058077f861ca2d6df95`, providing primitives, not this contract.

The [specification decision record](../release-scope.md) describes the publisher
choice and exact proposed production envelope. This artifact does not assert
compatibility with an unidentified `mosaic-contracts` revision. A breaking
change to these obligations requires a new contract version and consumer review.

## Domain-local record transfer

The write producer and FIFO write interface share `i_w_clk`. The FIFO read
interface and consumer share `i_r_clk`. Both clocks use rising-edge acceptance.
The payload is one opaque `DATA_WIDTH`-bit record, without packet, route, context,
or arithmetic interpretation.

```text
push = i_w_valid && o_w_ready  at a rising i_w_clk edge
pop  = o_r_valid && i_r_ready  at a rising i_r_clk edge
```

Valid must be offered independently of ready. A producer with an outstanding
offer must hold valid and the entire payload until local acceptance or epoch
cancellation. Consumer ready may be generated independently of valid. While
read valid is high and ready is low, the FIFO must hold read valid and payload
until local acceptance or cancellation. Reset cancellation ends these hold
obligations, including any offer outstanding during initialization.

Accepted records must be presented in acceptance order without duplication or
loss within an uninterrupted operational epoch. Delivery requires continuing
read-clock edges and consumer readiness. There is no unconditional liveness
guarantee when a clock stops, ready remains low, or reset never releases.
Previously delivered records are not outstanding FIFO obligations at cancellation.

Known clocks, resets, valid and ready are required. Payload X/Z bits remain
opaque data in four-state simulation and must not be interpreted as control.
There is no hardware error channel. Two-state verification does not establish
X/Z transport or unknown-control detection.

## Initialization, status and visibility

No write is accepted before `o_w_init_done`. No read is offered before
`o_r_init_done`. Each endpoint waits for its relevant local initialization
indication, not an assumed simultaneous global indication. A valid offer made
before initialization still follows the producer hold/cancellation obligation.
The current SVA/formal producer checks are scoped to initialized epochs, so
this pre-initialization obligation requires independent verification review.

```text
o_w_ready = o_w_init_done && !o_w_full
o_r_valid = o_r_init_done && !o_r_empty
```

The write occupancy estimate is conservative high and the read estimate is
conservative low during initialized, uninterrupted operation. Neither is a
coherent global count. Almost flags are threshold advisories, not transfer
permission. Use the local ready-valid handshake for acceptance.

The output head is registered before valid is asserted. Locally visible
successive records may be consumed on successive read rising edges. Pointer
visibility, initialization and full/empty changes have phase-dependent latency
through the synchronizers and local flag update. There is no fixed latency in
a shared clock, and no combinational ready/valid/status/reset path may cross
between domains. Qualified storage and crossing constraints remain required.

## Reset ownership and epoch cancellation

Both raw resets are active low, asynchronously asserted and externally released
synchronously to their local clocks. The integrating repository supplies one
coordinated reset controller and a qualified local reset synchronizer per
domain. The FIFO does not generate reset or synchronize reset release.

The system cancellation policy must:

1. Stop or cancel both endpoint protocols under the same cancellation event.
2. Assert both raw resets, with overlap, allowing domain assertion skew.
3. Meet each domain's qualified local reset pulse-width requirement.
4. Release each reset synchronously to its own running clock.
5. Resume each endpoint only after its relevant local `init_done` indication.

Any raw reset assertion cancels buffered records, outstanding offers and pending
delivery obligations of the old epoch. The FIFO does not expose a separate
cancellation port. Endpoint record owners, scoreboards and downstream commit
policy must receive the system cancellation event. Storage is unreset and its
old contents do not become new-epoch valid records.

Local reset clears local pointers, synchronizers, domain-up state, registered
levels and flags. Full and empty reset to one, levels to zero, and read output
data to zero. During local uninitialized operation the interface remains blocked.

## Unexpected one-sided reset

An unexpected unilateral raw reset immediately cancels the system epoch, even
though the peer may continue handshaking until the synchronized down marker
arrives. Any propagation-window traffic belongs to the canceled epoch and
must be discarded by the endpoint/system cancellation policy. FIFO status
cannot retrospectively revoke downstream side effects.

After a previously observed peer goes down, local domain-up remains low until
the local raw reset also asserts. Releasing only the reset side is not a safe
recovery. Perform the coordinated sequence above before either endpoint treats
the channel as operational again.

Either clock may stop indefinitely. A stopped peer cannot observe a down marker
or complete initialization. Hold the affected reset until visibility is assured
or assert the peer raw reset as part of coordinated recovery. Restart clocks
before synchronized reset release. An invisible short unilateral pulse is
outside this contract and must not be treated as automatic safe recovery.

Reset visibility and recovery/removal budgets must be reviewed for the actual
clock rates, synchronizer depth, libraries and implementation. The formal model's
bounded extra capture edge is not an analog guarantee or a universal minimum
reset pulse-width rule.

## Adoption and release evidence

A consumer must pin the approved contract repository revision and version,
review its reset/cancellation controller and endpoint obligations, and select
an approved exact production tuple. Qualification evidence must also retain
the common gitlink and this artifact's content hash.

The [interface](../interface.md) defines all ports, structural parameter legality
and threshold expressions. The [formal model](../formal-model.md) documents its
additional discrete capture/reset assumptions. The
[verification plan](../verification-plan.md) and
[release checklist](../release-checklist.md) record remaining proof, coverage,
CDC/RDC, timing, reliability and publication obligations. No passing portable
test or draft version label by itself approves adoption or ASIC release.
