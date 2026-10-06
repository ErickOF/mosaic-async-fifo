# Repository structure

## Design goal

Each module repository must be independently understandable, verifiable, and
releasable before system integration. The hierarchy separates design-owned
intent from the independently versioned shared methodology.

```text
module-repository/
|-- .github/                 Portable module CI and evidence checks
|   |-- scripts/             CI-owned release-evidence validators
|   `-- workflows/           Native and containerized quality gates
|-- config/                  Cross-flow configuration and qualification policy
|   `-- examples/           Non-default manifest examples and fixtures
|-- docs/                    Design contract and engineering records
|-- filelists/               Ordered source manifests
|-- flows/                   Module-owned inputs for shared flow adapters
|-- mosaic-flow/             Pinned methodology Git submodule
|-- reports/                 Generated reviewable results
|-- rtl/                     Synthesizable SystemVerilog
|-- verif/                   TB, PyUVM, properties, assertions, formal, coverage
|-- work/                    Disposable tool databases and generated artifacts
|-- Dockerfile               Reproducible portable-tool environment
|-- Makefile                 Thin importer of the shared Make API
`-- README.md                Repository overview and common commands
```

## Source hierarchy

### `rtl/`

Contains only synthesizable module RTL and public packages. Keep generated
netlists and tool output under `work/`. If a source is generated, commit its
generator and document whether the generated RTL is also authoritative.

### `verif/`

Organize verification by purpose:

```text
verif/
|-- properties/             Shared sequences and temporal properties
|-- assertions/             Assertion checker and simulation bind wrapper
|-- coverage/               HDL coverage model and simulation bind wrapper
|-- formal/                 Formal harnesses and assumptions
|-- mutations/              Deliberately incorrect qualification fixtures
|-- pyuvm/                  Python tests, agents, monitors, and scoreboards
|-- tb/                     Unit-level SystemVerilog testbench and tests
`-- models/                 Optional reference models
```

Shared verification libraries may be dependencies, but this repository remains
responsible for proving its module without relying on a full MOSAIC integration.

### `filelists/`

File lists are ordered source manifests and form part of the build contract:

- `rtl.f` contains synthesizable sources and include directories.
- `properties.f` supplies include paths or sources shared by checking layers.
- `assertions.f` contains assertion checkers and their bind wrappers.
- `coverage.f` contains HDL coverage models and their bind wrappers.
- `tb.f` imports RTL plus SystemVerilog testbench sources.
- `formal.f` composes RTL, shared properties, assertions, and the formal harness.

Use paths that resolve from the repository root. Keep tool-specific command-line
options out of shared file lists unless every consuming adapter supports them.
Normal simulation and PyUVM append the property, assertion, and coverage lists
to their primary source list. Formal configurations compile the same wrappers
explicitly. This keeps temporal behavior in one design-owned implementation.

## Configuration hierarchy

### `config/design.mk`

Defines module identity and the paths exported to all shared adapters. It also
provides optional technology and activity inputs for licensed implementation
flows.

### `config/flows.mk`

Defines project policy. Every canonical flow is explicitly enabled or disabled,
and project-specific dependencies may replace shared defaults.

Versioned JSON policies beside these Make fragments define machine-readable
qualification intent. `coverage-policy.json` sets HDL and formal coverage
requirements, `qualification-campaigns.json` defines expected-failure and
four-state controls, and `static-intent.json` describes the SDC and UPF subset
that must be present. A production parameter matrix normally belongs in
`config/parameter-profiles.json`. The template keeps its demonstration matrix
under `config/examples/` so the no-profile single-module command remains valid.

### `flows/`

Contains module-owned inputs grouped by the shared adapter that consumes them:

| Directory | Module-owned intent |
| --- | --- |
| `cdc/` | Clocks, resets, synchronizers, and intentional crossings |
| `eqy/` | Golden and gate setup plus equivalence strategies |
| `openroad/` | PDK-backed design configuration and timing constraints |
| `sg_dft/` | Test clocks, modes, resets, and exclusions |
| `symbiyosys/` | Proof and cover modes, engines, sources, and formal top |
| `synthesis/` | Synthesis timing constraints |
| `vc_lp/` | UPF power domains, supplies, states, isolation, and retention |
| `verible/` | Style policy and reviewed style waivers |
| `verilator_lint/` | Reviewed Verilator control-file waivers |

The matching directory under `mosaic-flow/flows/` contains invocation logic.
This repository's directory contains design intent. A methodology update can
therefore improve a tool adapter without silently replacing module constraints.

## Shared methodology

`mosaic-flow/` is a Git submodule pinned by the parent repository gitlink. The
root Makefile imports:

```make
include $(FLOW_ROOT)/mk/project.mk
```

`project.mk` loads the normal single-module configuration when no module
manifest exists. It activates validated project selection when
`config/modules.json` is present. Keep this Makefile thin. New reusable targets
belong in `mosaic-flow`. New module inputs belong in `config/design.mk`, a
selected module configuration, or the matching module-owned flow directory.

The complete shared hierarchy is documented in
[`mosaic-flow/docs/architecture.md`](../mosaic-flow/docs/architecture.md).

## Generated data

### `reports/`

Contains statuses, logs, and compact summaries intended for review or CI
retention. The first file to inspect is usually
`reports/<canonical-flow-id>/status.txt`. Parameter profiles and selected
modules insert their names before the flow ID. Release manifests are separated
again by execution context under `reports/release_manifest/<context>/`.

### `work/`

Contains disposable executables, netlists, proof databases, and tool state. It
must never be treated as source.

Both directories are ignored by Git. `make clean` removes generated work and
flow reports while preserving the report root placeholder.

## Container and CI ownership

The GitHub workflow validates the module with the exact `mosaic-flow` revision
recorded by the gitlink. It runs native and containerized portable checks plus a
dedicated containerized Nangate45 physical fixture. Generated ownership and
submodule cleanliness are checked before evidence is uploaded.

The Dockerfile copies only the executable shared methodology into the image.
The module repository is mounted at runtime, which keeps RTL and generated
reports outside the image and lets local and CI execution use the same source
tree.

Commercial tools, licenses, PDKs, and proprietary libraries remain outside the
container and GitHub-hosted runners. They are supplied only by the authorized
local or self-hosted environment.

## Source of truth

When artifacts disagree, use this order:

1. RTL and design-owned configuration in the module revision
2. The pinned `mosaic-flow` implementation for execution semantics
3. Machine-readable status and reports for a specific run
4. Documentation describing the intended contract

Correct any disagreement before release. A passing tool result does not excuse
stale interface or verification documentation.

## Multi-module variation

The hierarchy above defines one `MODULE_ROOT`. A repository that owns several
related modules repeats this hierarchy under `modules/<name>/` and keeps one
repository-level `mosaic-flow` submodule. See
[Multi-module repositories](multi-module-repositories.md) for the directory
contract, CI manifest, matrix execution, regression model, and integration
ordering.
