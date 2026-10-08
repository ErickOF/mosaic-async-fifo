# Reviewed waivers

[Return to the documentation index](README.md).

No functional, CDC/RDC, MTBF, timing, power, or physical signoff waiver is approved.

## Candidate style policy

ID: STYLE-001
Tool and rule: Verible `parameter-name-style`
Affected file and object: `rtl/async_fifo.sv` local parameters only
Technical justification: issue #1 names public derived widths in upper snake
case, matching the other public parameters. The scoped rule permits that
spelling without disabling other lint checks.
Evidence: `flows/verible/waivers.txt`, portable lint log
Owner: module maintainer
Reviewer: pending maintainer approval
Created: 2026-10-05
Removal condition: approved common naming policy or equivalent rename of the
documented contract. This development policy is not final waiver approval.

## Simulation-only diagnostic policy

ID: TB-001
Tool and rule: Verilator `ZERODLY`
Affected file and object: runtime-period delays in `async_fifo_tb.sv` and the
bounded reset-observation delay in `async_fifo_timing_coverage.sv` only
Technical justification: every assigned half-period is positive; the passive
reset window has an explicit lower bound of 32 ns. The warning
reports a possible zero delay for values not statically known. A source-local
directive bounds the diagnostic control to these delays, never production RTL.
Evidence: fixed/randomized positive-period scenarios and bounded reset samples
Owner: module maintainer
Reviewer: pending maintainer approval
Created: 2026-10-05
Removal condition: a supported simulator can prove nonzero dynamic delays.

## Covergroup frontend diagnostic policy

ID: COV-001
Tool and rules: pinned Verilator `VARHIDDEN` and `UNUSEDSIGNAL`
Affected files and objects: only native covergroup declarations in
`async_fifo_state_covergroups.svh` and `async_fifo_timing_coverage.sv`
Technical justification: generated sampler argument copies shadow themselves,
and generated internal/options/get-coverage scaffolding is unused. Narrow
source-local directives end before object instances and sampling observers.
Unused observer state, production RTL warnings, and `COVERIGN` diagnostics are
not suppressed. Native per-bin identity controls verify the groups are present.
Evidence: per-profile native databases and isolated cross artifact controls
Owner: module maintainer
Reviewer: pending maintainer approval
Created: 2026-10-07
Removal condition: simulator upgrade fixes generated-scaffolding warnings.
This candidate diagnostic policy is not an approved quantitative exclusion.

## Informational synthesis messages

Yosys reports replacement of synchronizer arrays with register lists. This is
expected for explicit flop chains, not an inferred payload memory reset. The
message is retained, not suppressed. Mapped preservation and stage fanout review
remain mandatory and open.

## Exclusions

Quantitative coverage exclusions are not yet approved. Missing licensed evidence
must remain NOT_RUN/BLOCKED. The Icarus immediate-monitor branch is a frontend
compatibility model, not evidence that concurrent SVA ran in Icarus.
