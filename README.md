# MOSAIC asynchronous FIFO

Parameterizable dual-clock FIFO for opaque MOSAIC records. The RTL top is
`async_fifo`. Development is tracked by
[issue #1](https://github.com/ErickOF/mosaic-async-fifo/issues/1).

## Architecture

- Locally owned binary pointers with Gray-coded pointer crossings.
- Exactly `SYNC_STAGES` synchronizer registers per crossing.
- Registered local full, empty, and conservative occupancy estimates.
- Registered prefetched output, stable under backpressure.
- Coordinated reset and synchronized domain-up handshake.
- Sticky shutdown after an observed one-sided reset until coordinated recovery.

Memory contents are not reset. This is an always-on, same-voltage unit-level
profile. Technology-specific storage, metastability, reset-domain, timing, and
power qualification are still required before ASIC release.

## Run

```sh
git submodule update --init --recursive
make profile-manifest-check
make PROFILE=nominal flow-config-check
make PROFILE=nominal open-source
make all-profiles PROFILE_JOBS=2 PROFILE_TARGET=open-source
```

The root Makefile consumes pinned `mosaic-flow` release `MF20260910V1`.
Tools are installed in `${XDG_CACHE_HOME:-$HOME/.cache}/mosaic`. Work and reports
are isolated under `work/<profile>/` and `reports/<profile>/`.

Standalone `yosys_synthesis` and `eqy_equivalence` are disabled at the FIFO
unit level and report policy `SKIP` locally and in GitHub Actions. Formal
verification remains enabled and still uses Yosys internally for model
preparation. These skips do not waive technology-mapped integration checks.

The [proposed first-release envelope](docs/release-scope.md#parameter-envelope)
contains five exact parameter tuples, including their resolved thresholds.
Scope approval is pending. The profiles do not qualify the Cartesian product
of their widths, depths, stages or thresholds, and do not authorize ASIC release.

## Verification

Independent queue scoreboard, bound assertions, separate HDL coverage, and
multiclock formal reference storage are included. The original `minimum` proof
is complemented by a separate nine-target matrix for depth four, two-bit
payloads, three stages, runtime cancellation and variable first-stage capture.
Each exact profile needs independent proof and cover evidence. See
[formal models and scope](docs/formal-model.md). Icarus campaigns exercise
mixed known/X/Z payloads, external and final-synchronizer unknowns with paired
disabled-monitor controls, invalid parameters and injected output corruption.
The automated negative campaign also detects actual pointer/domain-up stage,
flag and memory faults, plus a PyUVM producer-offer assertion fault. See the
[fault campaign scope](docs/verification-plan.md#negative-and-four-state-plan).

PyUVM runs on Verilator by default for all five profiles, including GitHub
Actions. Its independent queue scoreboard covers full/empty boundaries,
backpressure, wraps, conservative levels, coincident/unequal/drifting clocks,
both stopped-startup directions, no-bubble reads, skewed reset assertion, and
coordinated/unilateral reset recovery. A dedicated equal-nominal-rate drift case
requires five measured relative-phase ranges and balanced slow/fast intervals.
Six stopped-clock reset cases cross write/read/both clocks with both assertion
orders and require checked delivery after coordinated recovery. See the
[scenario matrix](docs/verification-plan.md#reset-and-phase-scenario-matrix).
The simulator compiles the same property, assertion, and HDL coverage sources
used by normal simulation and formal. Python scenario evidence is separate.
The [HDL coverage model](docs/coverage-model.md) implements all twelve required
coverage items in twenty native cross families. Per-bin hit/zero-hit evidence
is retained separately for each simulator and profile, not inferred from
scenario counters. Quantitative closure and assertion-vacuity review remain open.

```sh
make PROFILE=nominal open-pyuvm
./.github/scripts/check-pyuvm-evidence.sh reports/nominal/pyuvm_open_source
```

See [PyUVM configuration](docs/project-configuration.md#pyuvm-and-shared-verification).
Quantitative coverage closure, broader formal parameters, assumption/vacuity
review and expanded mutation campaigns
remain open. Commercial PyUVM has not been executed or qualified for this FIFO.

## Dependencies and Integration

`mosaic-common` is a Git submodule at `submodules/mosaic-common`, checked out
at the user-selected release `MC20261005V1`. The parent repository's gitlink
pins its immutable revision. `.gitmodules` records its path and repository URL.
The initialization command above fetches this dependency and its nested submodules.
The FIFO instantiates common `counter` modules for its wrapping binary pointers
and common `dff` banks for local Gray, domain-up, status, and read-output state.
The source filelist reads these directly from the pinned submodule. Dedicated
CDC chains and unreset payload storage remain local to the FIFO.
The system integrator provides coordinated reset and one local reset
synchronizer per clock domain.
The selected common release has no versioned ready-valid/reset-cancellation
artifact. The proposed FIFO-owned
[`AFIFO-CHANNEL-V1`](docs/contracts/async-fifo-channel-v1.md) extracts the issue's
existing behavior. Publisher approval, amendment of the issue's
`mosaic-contracts` references and immutable publication remain pending. Common
RTL dependency selection is not protocol approval. See the
[specification decision record](docs/release-scope.md).

## Release Status

This is an initial portable implementation, not a qualified ASIC release.
Mandatory VC Lint, CDC/RDC, synchronizer MTBF, mapped synthesis review,
PrimeTime, and PrimePower are NOT_RUN or BLOCKED. Disabling their adapters in
the portable configuration is not a waiver. No release identifier is assigned.

See the [documentation index](docs/README.md),
[interface](docs/interface.md), [verification plan](docs/verification-plan.md),
and [release checklist](docs/release-checklist.md).
