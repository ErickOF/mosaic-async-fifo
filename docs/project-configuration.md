# Project configuration

## Configuration layers

The module consumes shared defaults and then applies design-owned policy:

1. `mosaic-flow/mk/project.mk` selects the single-module or manifest-backed
   project mode.
2. `config/design.mk` defines module identity, paths, and technology inputs.
3. `mosaic-flow/config/tools.mk` defines pinned tool locations and command
   defaults.
4. `mosaic-flow/config/flows.mk` defines canonical flow states and dependencies.
5. Module `config/flows.mk` replaces shared states or dependencies.
6. A selected parameter profile narrows flows and overrides parameters or tops.
7. Make command-line assignments provide temporary diagnostic overrides.

The root Makefile establishes this order. Keep it free of design-specific flow
logic.

## Module identity

These values must agree with the RTL and verification hierarchy:

| Variable | Meaning | Template value |
| --- | --- | --- |
| `DESIGN_TOP` | Synthesizable top | `mosaic_module` |
| `TB_TOP` | Simulation top | `mosaic_module_tb` |
| `FORMAL_TOP` | Formal harness top | `mosaic_module_formal` |
| `PYUVM_TOP` | HDL top exposed to cocotb | `mosaic_module` |
| `PYUVM_TEST_MODULE` | Importable Python test module | `test_mosaic_module` |
| `DUT_INSTANCE` | Hierarchical DUT for SAIF annotation | `mosaic_module_tb/dut` |

`DUT_INSTANCE` uses the hierarchy syntax expected by PrimePower activity
annotation. Confirm it against the generated SAIF hierarchy rather than assuming
the simulation source name is sufficient.

## Paths

`FLOW_CONFIG_ROOT` points to the module-owned `flows/` directory. Other exported
paths identify:

- RTL, simulation, property, assertion, and coverage file lists
- PyUVM test path, Python module, HDL top, and DUT file list
- Verible and Verilator waiver policy
- Formal proof, formal cover, and equivalence configuration
- OpenROAD design configuration
- Synthesis, CDC, DFT, and UPF intent
- Report and work roots

Prefer absolute paths derived from `MODULE_ROOT`. Tool adapters may change their
working directory, while the module contract should remain stable.

The current Design Compiler adapter reads
`$(CONSTRAINT_DIR)/timing.sdc`. Keep `SYNTHESIS_CONSTRAINT_FILE` consistent with
that file.

Qualification paths include `COVERAGE_QUALIFICATION_POLICY`,
`QUALIFICATION_CAMPAIGN_MANIFEST`, `STATIC_INTENT_CONFIG`,
`OPENROAD_EVIDENCE_POLICY`, and the optional
`PARAMETER_PROFILE_MANIFEST`. Keep these files versioned and below
`MODULE_ROOT` so release evidence can hash them.

## Flow states

Every canonical flow has an explicit module policy:

```make
FLOW_verilator_sim := enabled
FLOW_pyuvm_open_source := enabled
FLOW_openroad := disabled
```

Only `enabled` and `disabled` are valid. Disabled flows record `SKIP` when their
target is invoked. The quality gate requires `PASS` for enabled flows and
`SKIP` for disabled flows.

The template enables normal Verilator simulation, open-source PyUVM, coverage
qualification, negative testing, four-state testing, and static-intent checks
in the portable gate. OpenROAD is enabled only by the dedicated physical job.
All commercial flows are disabled by default and must be enabled deliberately
in a qualified licensed environment.

Run:

```sh
make flow-config-check
```

Review the output after every state or dependency change.

Coverage qualification depends on the normal Verilator simulation artifact:

```make
FLOW_DEPENDENCIES_coverage_qualification := verilator_sim
```

The validator rejects an enabled flow whose dependency is disabled, as well as
unknown IDs, cycles, and contradictory aggregate policy.

## Parameter profiles

The example `config/examples/parameter-profiles.json` qualifies `DATA_WIDTH`
values 1, 32, and 64 without making profile selection mandatory for the normal
single-module command. Validate and run it with:

```sh
make PARAMETER_PROFILE_MANIFEST=config/examples/parameter-profiles.json \
  profile-manifest-check
make PARAMETER_PROFILE_MANIFEST=config/examples/parameter-profiles.json \
  profile-list
make PARAMETER_PROFILE_MANIFEST=config/examples/parameter-profiles.json \
  profile-matrix
make PARAMETER_PROFILE_MANIFEST=config/examples/parameter-profiles.json \
  all-profiles PROFILE_JOBS=3
```

Production modules should move their reviewed manifest to
`config/parameter-profiles.json`. Once that default exists, ordinary flow
targets require `PROFILE=<name>`. Each profile receives isolated
`reports/<profile>/` and `work/<profile>/` trees. `all-profiles` uses bounded
parallel execution and fails when any child fails or lacks required evidence.

## Qualification and release inputs

The module-owned policy files use versioned schemas supplied by the pinned
methodology:

| Input | Purpose |
| --- | --- |
| `config/coverage-policy.json` | Independent line, branch, toggle, user, named coverpoint, and formal-cover requirements |
| `config/qualification-campaigns.json` | Positive controls, expected failures, mutations, and Icarus X/Z detection |
| `config/static-intent.json` | Expected timing kind, SDC commands and ports, profile consistency, and UPF structure |
| `flows/openroad/evidence-policy.json` | Required physical artifacts, report patterns, and metric thresholds |

Run the gates independently with `make open-coverage`,
`make open-negative`, `make open-four-state`, and
`make open-static-intent`. See [Qualification and release
evidence](qualification.md) for their evidence and signoff boundaries.

## PyUVM and shared verification

PyUVM does not import or invoke SystemVerilog assertions. The Python test drives
and observes `PYUVM_TOP` through cocotb. During model construction, the shared
adapter compiles the following HDL layers in order:

1. `PYUVM_FILELIST` for the DUT and required packages
2. `PROPERTY_FILELIST` for shared sequence and property definitions
3. `ASSERTION_FILELIST` for assertion checkers and bind wrappers
4. `COVERAGE_FILELIST` for HDL coverage models and bind wrappers

The simulator therefore evaluates SVA and HDL coverage concurrently with the
Python-driven test. A terminating SVA failure also fails the PyUVM flow. Normal
SystemVerilog simulation uses the same property, assertion, and coverage lists.
The SymbiYosys proof and cover configurations explicitly instantiate the same
wrappers because open-source formal frontends do not reliably apply
simulation-oriented `bind` statements.

The main module-owned settings are:

| Variable | Purpose |
| --- | --- |
| `PROPERTY_FILELIST` | Shared sequences and temporal property definitions |
| `ASSERTION_FILELIST` | Assertion checker and bind wrapper sources |
| `COVERAGE_FILELIST` | HDL coverage model and bind wrapper sources |
| `PYUVM_FILELIST` | DUT sources compiled for the PyUVM HDL top |
| `PYUVM_TOP` | HDL top visible to cocotb |
| `PYUVM_TEST_MODULE` | Importable Python module containing decorated PyUVM tests |
| `PYUVM_TEST_PATH` | Directory prepended to the Python import path |
| `PYUVM_COVERAGE` | Enables simulator-native coverage when set to `enabled` |
| `FORMAL_COVER_CONFIG` | SymbiYosys cover reachability configuration |

Run the portable PyUVM flow directly with:

```sh
make open-pyuvm
```

The commercial policy is disabled in the template. In an authorized licensed
environment, enable `FLOW_pyuvm_commercial` and select the qualified backend:

```sh
make PYUVM_COMMERCIAL_SIMULATOR=vcs commercial-pyuvm
make PYUVM_COMMERCIAL_SIMULATOR=xcelium commercial-pyuvm
```

Both commercial backends consume the same Python test and shared SystemVerilog
verification layers. Simulator-specific compatibility and coverage options
must be qualified before they become release evidence.

`reports/pyuvm_open_source/coverage.dat` and `coverage.info` are native HDL
coverage evidence. `functional-coverage.json` is produced by the Python test
and remains a separate verification artifact. Neither form replaces the other.
The complete adapter contract and optional simulator settings are documented in
the shared
[configuration reference](../mosaic-flow/docs/configuration.md#design-and-path-variables).

## Dependencies

Dependencies use canonical flow IDs and replace the complete shared dependency
list:

```make
FLOW_DEPENDENCIES_eqy_equivalence := yosys_synthesis
FLOW_DEPENDENCIES_synopsys_primepower := vcs_sim synopsys_synthesis
```

The configuration validator rejects unknown IDs, self dependencies, cycles,
and enabled flows that depend on disabled flows. The runner requires every
dependency to record `PASS` before launching the dependent tool.

Use dependencies for real artifact or policy requirements. Do not add edges
only to force a preferred display order.

## Diagnostic overrides

A one-run Make assignment can inspect a different policy without editing the
project file:

```sh
make FLOW_symbiyosys_formal=disabled open-source
make CDC_TOOL=sg synopsys-cdc
```

`FORCE_FLOW=1` may execute one disabled flow for diagnosis:

```sh
make open-formal FORCE_FLOW=1
```

The flow remains disabled in project policy, so the aggregate gate still expects
`SKIP`. Do not use force mode as release evidence.

## Technology setup

Commercial implementation uses environment-provided site data:

| Variable | Purpose |
| --- | --- |
| `TECH_SETUP_TCL` | Optional setup sourced by synthesis, timing, and power Tcl |
| `TARGET_LIBRARY` | Target technology library used by site setup |
| `LINK_LIBRARY` | Link libraries used by site setup |
| `OPERATING_CONDITION` | Requested analysis corner used by site setup |
| `ACTIVITY_FILE` | SAIF activity consumed by PrimePower |

These values are empty or generic in the template. Supply them through the
authorized local environment. Never commit licenses, credentials, PDK paths, or
proprietary libraries.

## Tool executable overrides

The shared methodology defines executable defaults. Override them only when the
site installation uses a different command or wrapper:

```sh
make VERILATOR_CMD=/opt/verilator/bin/verilator open-lint
make SYNTH_BIN=/eda/synopsys/bin/dc_shell synopsys-synth
```

Do not pin open-source versions in this repository. Update the `mosaic-flow`
gitlink to a qualified release that carries the new version manifest.

## Updating the methodology revision

Fetch and inspect the candidate revision:

```sh
git -C mosaic-flow fetch origin
git -C mosaic-flow checkout --detach <qualified-commit>
git add mosaic-flow
```

Verify the parent gitlink and submodule checkout agree:

```sh
git submodule status
git ls-files -s mosaic-flow
git -C mosaic-flow rev-parse HEAD
```

Then rerun native, containerized, and applicable commercial gates. Review the
candidate's documentation and release notes for changed inputs, statuses, tool
versions, and policy before accepting the pointer update.

## Further reference

For multiple independently checked tops in one repository, apply this
configuration hierarchy separately in each module root. The repository-level
manifest and GitHub Actions matrix are documented in
[Multi-module repositories](multi-module-repositories.md).

The authoritative shared configuration semantics are documented in
[`mosaic-flow/docs/configuration.md`](../mosaic-flow/docs/configuration.md).
The complete flow IDs, inputs, outputs, and tool references are in the shared
[flow catalog](../mosaic-flow/docs/flows.md).
