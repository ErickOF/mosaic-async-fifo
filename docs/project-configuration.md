# Project configuration

The root Makefile directly includes `mosaic-flow/mk/project.mk`.
`config/design.mk` selects `async_fifo`, source lists, and module-owned inputs.
`config/flows.mk` selects the initial portable flows. No new per-flow Makefile
or runner is introduced.

## Profiles

Always select `PROFILE=<name>` or run `make all-profiles PROFILE_JOBS=2`.
The manifest at `config/parameter-profiles.json` is the source of truth.
Profiles isolate reports, generated netlists, and work directories.

The pinned MF20260910V1 parameter renderer applies Yosys overrides separately
in alphabetical order. A threshold valid only after a depth increase can fail
during an intermediate override. The `wide_deep` profile uses derived default
thresholds, and `threshold_edges` exercises upper boundaries at default depth.
The RTL guard remains intact. Atomic grouped override support should be qualified
in a future mosaic-flow release rather than patched into this submodule.

## Portable and licensed scopes

Verible style/format, Slang, Verilator lint/simulation, PyUVM, and the
negative/four-state campaigns are enabled where named by each profile.
Within the portable matrix, multiclock formal is enabled only for `minimum`.
The separate `config/formal-profiles.json` provides nine formal-only targets,
using the same pinned adapter with a manifest override. See
[formal models and commands](formal-model.md). Do not use those harness-only
parameters with production simulation or synthesis tops.

The owner has disabled standalone `yosys_synthesis` and `eqy_equivalence` at
the FIFO unit level. Neither is required by the five portable profiles.
The shared `open-source` gate records both as policy `SKIP`, including in
GitHub Actions. Explicit `open-synth` and `open-equivalence` targets also skip
without invoking their adapters. SymbiYosys remains enabled and uses Yosys for
formal model preparation independently of those standalone flows.

Synthesis/equivalence collateral and the EQY-to-synthesis dependency are retained
for possible future use. Re-enabling them requires both flow flags and the
applicable profile lists to be updated. Existing PASS evidence is historical,
not a result for the current disabled policy. Technology-mapped integration
qualification remains required and is not authorized by these skips.

Quantitative coverage qualification and portable static intent remain
unqualified. The existing static-intent parser does not qualify this module's
Gray-bus skew, mapped endpoint, and RDC requirements.

Licensed flows are disabled in the portable profile because tools, libraries,
corners, and qualified site adapters are not configured. VC Lint, a selected
CDC/RDC engine, mapped synthesis/preservation, PrimeTime, PrimePower, and MTBF
are still mandatory release requirements. They are NOT_RUN/BLOCKED, not waived.

DFT, VC LP, and physical scope depend on the eventual product integration.
The draft SDC deliberately fails closed until mapped crossing endpoints and
physical budgets are qualified. The UPF is a same-voltage always-on draft.

## PyUVM and Shared Verification

`FLOW_pyuvm_open_source=enabled` and every profile's flow list select the shared
Verilator adapter. `make PROFILE=<name> open-source` therefore runs PyUVM in
addition to the SystemVerilog testbench. `make PROFILE=<name> open-pyuvm` runs
only that adapter. No new runner, per-flow Makefile, HDL wrapper, or dependency
version is needed.

`PYUVM_TOP=async_fifo` exposes the DUT ports directly. `PYUVM_TEST_MODULE=test_async_fifo`
selects `verif/pyuvm/test_async_fifo.py`, which creates `FifoEnvironment` from
`verif/pyuvm/async_fifo_env.py`. The shared adapter passes
`PROFILE_PARAMETERS_JSON` to both HDL elaboration and Python. Python derives
the depth-dependent default thresholds when they are absent from the manifest.

PyUVM does not call or import SVA or HDL coverage. The shared runner compiles:

1. `filelists/rtl.f`, including common `dff` and `counter` sources.
2. `filelists/properties.f`, supplying the shared predicate include path.
3. `filelists/assertions.f`, compiling the checker and its DUT bind.
4. `filelists/coverage.f`, compiling the HDL coverage model and its DUT bind.

Those bound modules execute inside the simulator alongside Python stimulus.
The same sources are used by the normal testbench and the explicit formal
instances. Python checks public-port ordering, conservative occupancy, and
scenario accounting independently; it does not implement another copy of the
Gray-pointer or protocol-hold SVA.

The BFM snapshots both interfaces before driving any scheduled rising edges.
Coincident edges therefore use the same pre-edge occupancy. It yields at
`ReadWrite` after driving clocks to settle HDL without advancing past the next
scheduled event. This follows the
[cocotb timing model](https://docs.cocotb.org/en/stable/timing_model.html).
Periods, stops, and phases are independently scheduled; there is no shared
hardware clock. Producer offers change on falling write edges and remain held
until a sampled acceptance or reset cancellation.

Reports live in `reports/<profile>/pyuvm_open_source/`:

| Artifact | Meaning |
| --- | --- |
| `status.txt`, `results.xml` | Adapter result and executed PyUVM JUnit test |
| `compile.log`, `simulation.log`, `run.log` | Build, stimulus/checker, and runner logs |
| `coverage.dat`, `coverage.info` | Simulator-native RTL, SVA, and HDL coverpoint data |
| `functional-coverage.json` | Separate Python scenario hits, profile, fixed seed, and epoch totals |
| `cross-coverage.json` | Individual native HDL cross bins, including zero hits; integrity only, no quantitative PASS |
| `versions.log` | Python, PyUVM, cocotb, and simulator identity |

`./.github/scripts/check-pyuvm-evidence.sh <report-dir>` rejects missing files,
SKIP/FAIL, empty/failed/skipped JUnit, missing shared HDL sources, wrong profile
parameters, unmet implemented scenario hits, or inconsistent reset accounting.
Native and container GitHub Actions jobs run this check after the portable gate.
It is an integrity/scenario check, not quantitative coverage release approval.
The existing quantitative coverage policy still selects `verilator_sim` and
remains disabled pending review. Evidence from the two simulations is not merged.

The PyUVM evidence script also calls `check-cross-coverage.py`. CI explicitly
runs that collector for `reports/<profile>/verilator_sim` as well. It rejects
missing/duplicate native cross identities; it does not discard zero-hit bins.
The [HDL model](coverage-model.md) documents clock/reset sampling, bin ranges,
the shared quantitative parser's unsupported `covergroup` metric, and the
remaining qualification/vacuity boundary. State-cross totals must match
independent qualified-event counters, and all crosses conserve component counts.
No new simulation backend is added.

The same test/filelists are configured for the shared VCS/Xcelium adapters, but
commercial PyUVM remains disabled and NOT_RUN until site qualification. Icarus
four-state campaigns remain separate; the default Verilator PyUVM result does
not qualify unknown payload/control behavior or metastability.

### Automated negative controls

`config/qualification-campaigns.json` selects a passing full PyUVM regression
and the `test_async_fifo_assertion_control` producer-offer fault in separate
case-specific report/work roots. `.github/scripts/run-pyuvm-control.sh` calls
the existing shared adapter and forwards the simulator log for the expected
named SVA diagnostic. Raw fault evidence stays FAIL. Only the shared campaign
can award expected-failure PASS, and only after its positive control passes.
The ordinary PyUVM regression is not replaced by the fault test.

The fault adapter writes its untouched reports under the case work root at
`work/raw-reports/minimum/pyuvm_open_source/`. Compact logs, JUnit and tool
identity are copied to the case report root at `reports/raw-pyuvm/`, with raw
status preserved as `raw-status.txt`. This separates expected simulator failure
from the campaign `status.txt` consumed by the recursive profile gate scanner.
GitHub Actions already archives the enclosing campaign reports, including this
raw evidence. A wrong diagnostic or unexpected success still fails the campaign.

Both nested PyUVM controls and the RTL-state fault baseline explicitly select
`PROFILE=minimum DISABLED_FLOWS=`. This clears the exported disabled-flow list
derived from the outer profile and recomputes policy for the fixed fixture.
It does not enable formal in the outer nominal profile or alter the pinned
methodology. `minimum` and `nominal` enable these campaigns by default through
`open-source`. See the [verification plan](verification-plan.md#negative-and-four-state-plan)
for the fixed fixture parameters and remaining fault coverage.

## Dependency baseline

The parent repository's gitlinks pin `mosaic-flow/` and
`submodules/mosaic-common/`. `.gitmodules` records their paths and URLs, so no
separate dependency manifest is needed. Initialize both with
`git submodule update --init --recursive`.

The common submodule is checked out at MC20261005V1. `filelists/rtl.f` includes
only its `dff` and `counter` sources, which the FIFO instantiates directly.
Formal staging, equivalence, negative campaigns, and the draft physical source
list include the same dependencies. No common source is copied or modified.
Formatting applies to FIFO-owned sources, not the pinned dependency's style.

Pointer counters use asynchronous reset, upward counting, and wrapping rather
than saturation. Clear/load inputs are inactive. Local `dff` banks use explicit
asynchronous reset values and capture enables. Dedicated synchronizer chains
retain their CDC attributes and payload storage remains unreset.
Integrating repos still provide reset synchronization/coordination.
MC20261005V1 supplies RTL primitives, not a versioned channel contract. The
proposed FIFO-owned [AFIFO-CHANNEL-V1](contracts/async-fifo-channel-v1.md) is
drafted from issue #1. Publisher approval, issue amendment and immutable
publication remain pending, separately from the common gitlink selection.

## Containers

```sh
docker build --build-context mosaic-flow=./mosaic-flow \
  --build-arg MOSAIC_FLOW_REVISION=0bd222f827afd802944d5f7e6ebc2ccc3a96f7ea \
  -t mosaic-async-fifo:portable .
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$PWD:/workspace" mosaic-async-fifo:portable \
  all-profiles PROFILE_JOBS=2 PROFILE_TARGET=open-source
```

Container and hosted CI results must be recorded separately from native evidence.
No dirty-tree release manifest is publishable. Mandatory gates are listed in
`RELEASE_SUPPLEMENTAL_GATES`, so the shared manifest collector also rejects
missing or SKIP ASIC, contract, coverage, and release-review evidence. Portable
CI does not generate a publishable release manifest.

`RELEASE_ADDITIONAL_INPUTS` uses the shared collector to hash the interface,
exact proposed scope and protocol/cancellation artifact. It does not create
`contract_review` PASS evidence. The release owner must record approval of the
artifact version, repository revision, content hash and selected tuple before
that supplemental gate can close.
