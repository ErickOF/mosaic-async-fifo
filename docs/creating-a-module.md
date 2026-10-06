# Creating a module

## Before editing

Create the new repository from this template using the organization's normal
GitHub or repository provisioning process. Clone it, then initialize the exact
shared methodology revision recorded by the template:

```sh
git submodule update --init --recursive
git submodule status
```

The submodule output must begin with a space. A leading `-` means it is not
initialized. A leading `+` means the checkout does not match the recorded
gitlink.

## Rename the example module

Choose one stable lowercase SystemVerilog identifier. Replace
`mosaic_module` in every design-owned source and configuration file:

```sh
rg -n "mosaic_module|MOSAIC_MODULE" \
  --glob '!mosaic-flow/**' \
  --glob '!reports/**' \
  --glob '!work/**'
```

At minimum, rename and update:

- `rtl/mosaic_module.sv`
- `verif/tb/mosaic_module_tb.sv`
- `verif/pyuvm/test_mosaic_module.py`
- Both files under `verif/properties/`
- `verif/assertions/mosaic_module_sva.sv`
- `verif/assertions/mosaic_module_bind.sv`
- Both files under `verif/coverage/`
- `verif/formal/mosaic_module_formal.sv`
- `verif/tb/mosaic_module_four_state_tb.sv`
- `verif/mutations/mosaic_module_bad_netlist.v`
- Every file under `filelists/`
- `config/design.mk`
- `config/coverage-policy.json`
- `config/qualification-campaigns.json`
- `config/static-intent.json`
- `config/examples/parameter-profiles.json`
- Both `config/qualification-*.eqy` files
- `flows/symbiyosys/formal.sby`
- `flows/symbiyosys/formal_cover.sby`
- `flows/eqy/equivalence.eqy`
- `flows/openroad/config.mk`
- `flows/openroad/evidence-policy.json`
- `flows/vc_lp/power.upf`
- This repository's title and documentation

Do not rename identifiers inside the `mosaic-flow` submodule. Shared methodology
must remain design-independent.

## Replace the example RTL

Define the synthesizable top in `rtl/` and update `DESIGN_TOP`. Keep the public
module contract small and explicit. Document:

- Parameters and legal values
- Ports, widths, directions, and signedness
- Clock and reset behavior
- Handshake and backpressure rules
- Latency and throughput
- Error handling
- Disabled and low-power behavior

Record the contract in [Interface specification](interface.md) before other
modules depend on it.

### SystemVerilog time declarations

Keep synthesizable RTL compatible with every enabled frontend. The pinned Yosys
frontend does not accept module-scoped `timeunit` and `timeprecision`
declarations in synthesizable source files. When a synthesizable file needs an
explicit simulation time scale, use a compilation-unit directive:

```systemverilog
`timescale 1ns/1ps
```

Testbench-only modules may use `timeunit` and `timeprecision` when every enabled
simulator and linter accepts them. Do not add delays to synthesizable RTL.

## Build authoritative file lists

Update `filelists/rtl.f` in dependency order. Add packages before modules that
import them and include directories before files that require them.

Update `filelists/properties.f`, `filelists/assertions.f`, and
`filelists/coverage.f` without duplicating those sources in `filelists/tb.f`.
The shared adapters append the reusable verification layers in that order.

Update `filelists/tb.f` with RTL and the unit testbench. Keep the simulation top
consistent with `TB_TOP`. Set `PYUVM_FILELIST` to the sources required by
`PYUVM_TOP`, normally `filelists/rtl.f`.

Update `filelists/formal.f` and both source lists under `flows/symbiyosys/`.
Keep the proof and cover tops consistent with `FORMAL_TOP`.

Run an early frontend check:

```sh
make open-elaborate
make open-lint
make open-pyuvm
make open-formal
```

## Replace the smoke verification

The example simulation proves only reset, enabled update, and disabled hold
behavior. Replace it with tests and checking derived from the new interface.

Update all of these together:

- Unit-level stimulus and scoreboards
- PyUVM stimulus, checking, and functional coverage
- Shared sequences and properties
- Bound assertion and HDL coverage wrappers
- Formal assumptions plus explicit reuse of the same wrappers
- [Verification plan](verification-plan.md)

Avoid assumptions that remove legal interface behavior from formal analysis.
Use negative tests to prove the testbench and assertions detect injected faults.

PyUVM does not call SVA from Python. Cocotb drives and observes the DUT while
the selected HDL simulator compiles the property, assertion, and coverage
filelists and evaluates their bound wrappers concurrently. Keep Python
functional coverage separate from simulator-native assertion, line, branch,
and toggle coverage. See
[Project configuration](project-configuration.md#pyuvm-and-shared-verification).

### Parameterized modules

Use a versioned `config/parameter-profiles.json` manifest when a production
module has several representative elaborations. The template demonstration
manifest remains under `config/examples/` so it can exercise the API without
making profile selection mandatory for ordinary single-module use.

For every parameter value that changes generated structure:

1. Exercise it in the self-checking simulation regression.
2. Include it in formal verification when practical.
3. Record whether synthesis and equivalence are required for that profile.
4. Declare the parameter map and required flows in the profile manifest.
5. Ensure the simulation and formal tops expose and propagate the parameter.
6. Run the bounded aggregate and retain its profile-local evidence.
7. Do not report a manual diagnostic command as release evidence unless its
   configuration, output, and status are retained reproducibly.

```sh
make profile-manifest-check
make profile-list
make profile-matrix
make all-profiles PROFILE_JOBS=4
```

The shared runner translates parameters to supported backends and isolates
results below `reports/<profile>/` and `work/<profile>/`. Do not add
module-specific profile orchestration to the thin Makefile.

## Configure design intent

### Timing

Define every clock, generated clock, input delay, output delay, uncertainty,
false path, and multicycle path in `flows/synthesis/timing.sdc`. Keep the
OpenROAD SDC aligned unless physical implementation intentionally uses a
different constraint set.

### CDC and reset crossings

Declare clock and reset domains in `flows/cdc/constraints.tcl`. Identify
synchronizers and intentional crossings. A comment is not a CDC waiver.

### DFT

Define test clocks, resets, modes, scan controls, and intentional exclusions in
`flows/sg_dft/constraints.tcl`.

### Low power

Replace the example UPF top and domain names in `flows/vc_lp/power.upf`. Add
power states, switches, isolation, retention, and level shifters required by the
architecture.

### Formal and equivalence

Set proof depth, engines, sources, and top in the SymbiYosys file. Configure EQY
to compare the intended golden RTL with the netlist generated by Yosys.

### Physical implementation

Set the design name, RTL sources, platform, SDC, utilization, aspect ratio, and
margin in `flows/openroad/config.mk`. Replace
`flows/openroad/evidence-policy.json` with required artifact paths and metric
thresholds for the selected platform. Keep `FLOW_openroad` out of the portable
default when its runtime is too heavy, then enable it explicitly in a dedicated
CI job or qualified local target.

The pinned container path is reproducible and requires no local ORFS checkout:

```sh
make FLOW_openroad=enabled \
  OPENROAD_EXECUTION_MODE=container \
  open-physical
```

Use `OPENROAD_EXECUTION_MODE=local` with `OPENROAD_FLOW_ROOT=<checkout>` for an
approved local ORFS tree. Public Nangate45 output is exploratory evidence and
must not be described as foundry signoff.

## Configure qualification policies

Replace the template policy values with module-owned requirements:

- `config/coverage-policy.json` defines quantitative native HDL, named
  coverpoint, and formal-cover closure.
- `config/qualification-campaigns.json` defines positive controls, mutations,
  expected failure signatures, and four-state cases.
- `config/static-intent.json` defines the timing-intent kind, SDC port coverage,
  intentional exceptions, cross-profile consistency, and required or forbidden
  UPF structures.
- `flows/openroad/evidence-policy.json` defines physical artifacts and metric
  thresholds.

Keep production RTL out of mutation cases and keep every command as a JSON
argument array. Add positive controls before negative cases so a broken tool or
always-failing monitor cannot masquerade as fault detection. Use a true
four-state simulator for X and Z controls.

## Select flows and dependencies

Review every state in `config/flows.mk`. Do not leave a flow disabled merely to
obtain a passing gate. A disabled state must reflect the module's reviewed
release policy.

Validate the resolved graph:

```sh
make flow-config-check
```

Keep artifact dependencies unless the module has a justified replacement:

```make
FLOW_DEPENDENCIES_eqy_equivalence := yosys_synthesis
FLOW_DEPENDENCIES_synopsys_primetime := synopsys_synthesis
FLOW_DEPENDENCIES_synopsys_primepower := vcs_sim synopsys_synthesis
```

See [Project configuration](project-configuration.md) and the shared
[configuration reference](../mosaic-flow/docs/configuration.md).

## Configure GitHub Actions

No additional GitHub Actions secret is required while `ECASLab/mosaic-flow`
remains public. CI uses the repository's standard read token to check out the
exact public methodology revision recorded by the module gitlink. If the
methodology becomes private, configure a separate read-only credential and
update the checkout policy deliberately.

Update Docker image labels if the new repository URL differs from the template.
Do not change the workflow to fetch a floating methodology branch. CI reads the
gitlink and checks out that exact commit.

## Run initial acceptance

Prepare tools and run from a clean generated state:

```sh
make setup-open-source
make clean open-source
./.github/scripts/check-pyuvm-evidence.sh
./.github/scripts/check-qualification-controls.sh
./.github/scripts/check-profile-evidence.sh
```

Build and validate the container path:

```sh
docker build \
  --platform linux/amd64 \
  --build-context mosaic-flow=./mosaic-flow \
  --build-arg MOSAIC_FLOW_REVISION="$(git -C mosaic-flow rev-parse HEAD)" \
  --tag module-ci:local \
  .

docker run --rm \
  --user "$(id -u):$(id -g)" \
  --env HOME=/tmp \
  --volume "$PWD:/workspace" \
  module-ci:local clean open-source

./.github/scripts/check-pyuvm-evidence.sh
```

Run exploratory physical acceptance separately:

```sh
make FLOW_openroad=enabled \
  OPENROAD_EXECUTION_MODE=container \
  open-physical
```

After all policy-required flows pass, generate and validate the indexed release
record from a clean tree:

```sh
make \
  MODULE_REVISION="$(git rev-parse HEAD)" \
  METHODOLOGY_REVISION="$(git -C mosaic-flow rev-parse HEAD)" \
  RELEASE_EXECUTION_CONTEXT=native \
  release-manifest release-manifest-validate
```

`RELEASE_ALLOW_DIRTY=enabled` is only a local diagnostic override. The manifest
records the dirty state and is not publishable release evidence.

In the licensed environment, qualify all enabled Synopsys adapters and run the
commercial gate. The placeholder VC Lint, CDC, SpyGlass DFT, and VC LP adapters
must not be mistaken for completed signoff.

## Remove template residue

Before the first review, confirm that:

- No design-owned file still contains `mosaic_module`
- Interface and verification documents describe the new module
- Example clock periods and delays have been replaced or justified
- UPF domain and supply intent matches the architecture
- Placeholder CDC and DFT comments have been replaced with real constraints
- Every waiver is reviewed and recorded
- The portable gate passes from a clean checkout
- Required commercial evidence is available or explicitly outside release scope
